defmodule Dashboard.StatsLive do
  @moduledoc false
  use Dashboard, :live_view

  import Stats.Event, only: [aggregate: 1, aggregate: 2]

  alias Dashboard.RateLimit
  alias Dashboard.StatsLive.Query
  alias Stats.Aggregate
  alias Stats.Domains
  alias Stats.Events
  alias Stats.EventsRepo
  alias Stats.Queryable

  require Logger

  @impl true
  def mount(params, session, socket) do
    {:ok, handle_mount(socket.assigns.live_action, params, session, socket)}
  end

  def handle_mount(_live_action, params, _session, socket) do
    {:ok, query} = Query.validate(params)

    socket
    |> authorized_domains(socket.assigns.live_action, query)
    |> available()
    |> assign(:version, version())
    |> assign(:edition, edition())
    |> configure_stream_for_aggregate_fields()
    |> assign(:query, query)
    |> then(fn socket ->
      headers = get_connect_info(socket, :x_headers) || []
      ip = RemoteIp.from(headers, clients: clients())
      assign(socket, :client_ip, :inet.ntoa(ip))
    end)
  end

  defp authorized_domains(socket, :host, query) do
    {:ok, host} = Map.fetch(query, :host)

    case Domains.get_by_host(host) do
      nil -> assign(socket, :domains, [])
      {:ok, domain} -> assign(socket, :domains, List.wrap(domain))
    end
  end

  defp authorized_domains(socket, :index, _query) do
    assign(socket, :domains, Domains.list_published())
  end

  defp configure_stream_for_aggregate_fields(socket) do
    Enum.reduce(aggregate_fields(), socket, fn field, socket ->
      socket
      |> stream_configure(field, dom_id: &dom_id/1)
      |> stream(field, [])
    end)
  end

  defp update_aggregate_streams(stream) do
    EventsRepo.transaction(fn ->
      stream
      |> EventsRepo.merge_columns()
      |> Enum.to_list()
      |> then_process()
    end)
  end

  defp then_process([]) do
    []
  end

  defp then_process([%{data: counts}, %{data: grouping_ids}, %{data: values}, %{data: maxes}]) do
    [counts, grouping_ids, values, maxes]
    |> Enum.zip_with(fn [count, grouping_id, value, max] ->
      aggregate(count: count, grouping_id: grouping_id, value: value, max: max)
    end)
    |> Enum.chunk_by(fn aggregate -> aggregate(aggregate, :grouping_id) end)
    |> Enum.map(fn [aggregate | _] = aggregates ->
      send(self(), {:aggregates, to_atom(aggregate(aggregate, :grouping_id)), aggregates})
      aggregate(aggregate, :grouping_id)
    end)
  end

  def to_atom(grouping_id) do
    {:parameterized, {_, %{on_load: on_load}}} = Stats.TypedAggregate.__schema__(:type, :grouping_id)
    Map.fetch!(on_load, grouping_id)
  end

  @impl true
  def handle_async(:fetch_aggregates, {:ok, %Stream{} = stream}, socket) do
    {:noreply,
     stream
     |> update_aggregate_streams()
     |> post_handle_async(socket)
     |> available()}
  end

  defp post_handle_async({:ok, []}, socket) do
    stream_empty_aggregates(socket)
  end

  defp post_handle_async({:ok, _}, socket) do
    socket
  end

  defp stream_empty_aggregates(socket), do: Enum.reduce(aggregate_fields(), socket, &stream(&2, &1, [], reset: true))

  @impl true
  def handle_info(:fetch_aggregates, socket) do
    key = socket.id
    scale = to_timeout(millisecond: 750)
    limit = 1

    case RateLimit.hit(key, scale, limit) do
      {:allow, _current_count} ->
        {:noreply, fetch_aggregates(socket)}

      {:deny, ms_until_next_window} ->
        schedule_fetch(ms_until_next_window)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:aggregates, field, aggregates}, socket) do
    {:noreply, stream(socket, field, aggregates, reset: true)}
  end

  defp schedule_fetch(in_ms) do
    Process.send_after(self(), :fetch_aggregates, in_ms)
  end

  def handle_event("scale", params, socket) do
    %{query: existing_query} = socket.assigns

    {:ok, query} = Query.validate(existing_query, params)

    {:noreply, patch(socket, query)}
  end

  def handle_event("limit", %{"_target" => [target]} = params, socket) when target in ["to", "from"] do
    %{query: existing_query} = socket.assigns

    params = Map.put(params, "interval", nil)

    {:ok, query} = Query.validate(existing_query, params)

    {:noreply, patch(socket, query)}
  end

  def handle_event("limit", %{"_target" => ["interval"]} = params, socket) do
    %{query: existing_query} = socket.assigns

    params =
      params
      |> Map.put("from", nil)
      |> Map.put("to", nil)

    {:ok, query} = Query.validate(existing_query, params)

    {:noreply, patch(socket, query)}
  end

  @impl true
  def handle_event("filter", %{"_target" => [target | []]} = params, socket) do
    %{query: existing_query} = socket.assigns
    proposed_query = Map.put_new(params, target, [])

    {:ok, query} = Query.validate(existing_query, proposed_query)

    {:noreply, patch(socket, query)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.domains do
      [_ | _] ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}

      [] ->
        {:noreply, socket}
    end
  end

  defp apply_action(socket, _, _params) do
    if available?(socket) do
      send(self(), :fetch_aggregates)
      unavailable(socket)
    else
      socket
    end
  end

  defp query_struct_to_query_params(%Query{} = query) do
    query
    |> Map.from_struct()
    |> Enum.reduce([], fn
      # reject host because it's a path param
      {:host, _}, params -> params
      # reject nils
      {_k, nil}, params -> params
      # everything else is okay
      kv, params -> [kv | params]
    end)
  end

  defp patch(socket, %Query{} = query) do
    query_params = query_struct_to_query_params(query)

    request_uri =
      case query do
        %{host: nil} -> ~p"/?#{query_params}"
        %{host: host} -> ~p"/#{host}?#{query_params}"
      end

    socket
    |> assign(:query, query)
    |> push_patch(to: request_uri)
  end

  defp dom_id(aggregate), do: "aggregate-#{Queryable.hash(aggregate)}"
  defp aggregate_fields, do: Aggregate.__schema__(:fields)

  embed_templates "stats_live_html/*", suffix: "_html"

  @impl true
  def render(%{domains: []} = assigns) do
    four_oh_four_html(assigns)
  end

  @impl true
  def render(assigns) do
    index_html(assigns)
  end

  # allow 127.0.0.1 as client_ip when in development
  if Application.compile_env(:stats, :dev_routes) do
    defp clients, do: ["127.0.0.1"]
  else
    defp clients, do: []
  end

  defp version do
    :stats |> Application.spec(:vsn) |> to_string()
  end

  defp edition do
    Application.fetch_env!(:stats, :edition)
  end

  defp fetch_aggregates(socket) when is_connected(socket) do
    query = socket.assigns.query
    filters = authorized_filters(query, socket.assigns.domains)

    start_async(socket, :fetch_aggregates, fn ->
      Events.stream_aggregates(filters)
    end)
  end

  defp fetch_aggregates(socket), do: socket

  # lists all authorized domains because nothing has been filtered
  defp authorized_filters(%{sites: nil, host: nil} = query, authorized_domains) do
    filters = Query.to_filters(query)

    sites =
      Enum.map(authorized_domains, fn domain ->
        TypeID.uuid(domain.id)
      end)

    Keyword.replace(filters, :sites, sites)
  end

  # filter by sites because host is not present
  defp authorized_filters(%{host: nil} = query, authorized_domains) do
    filters = Query.to_filters(query)

    sites =
      Enum.reduce(authorized_domains, [], fn authorized_domain, acc ->
        if authorized_domain.host in query.sites, do: [TypeID.uuid(authorized_domain.id) | acc], else: acc
      end)

    Keyword.replace(filters, :sites, sites)
  end

  # filter for the single /:host, ignoring query[:sites] because it has no effect when :host
  # is provided
  defp authorized_filters(%{host: host} = query, [authorized_domain | []]) when not is_nil(host) do
    filters = Query.to_filters(query)

    Keyword.replace(filters, :sites, [TypeID.uuid(authorized_domain.id)])
  end

  defp authorized_filters(_, _), do: []

  defp available(socket) do
    assign(socket, :available, true)
  end

  defp unavailable(socket) do
    assign(socket, :available, false)
  end

  defp available?(socket) do
    socket.assigns.available
  end
end
