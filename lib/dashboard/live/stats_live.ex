defmodule Dashboard.StatsLive do
  @moduledoc false
  use Dashboard, :live_view

  import Scouter.Event, only: [aggregate: 1, aggregate: 2]

  alias Dashboard.RateLimit
  alias Dashboard.StatsLive.Query
  alias Scouter.Aggregate
  alias Scouter.Events
  alias Scouter.EventsRepo
  alias Scouter.Queryable
  alias Scouter.Services

  require Logger

  @impl true
  def mount(params, session, socket) do
    {:ok, handle_mount(socket.assigns.live_action, params, session, socket)}
  end

  def handle_mount(_live_action, params, session, socket) do
    {:ok, query} = Query.validate(params)

    socket
    |> authorized_services(query)
    |> available()
    |> assign(:version, version())
    |> assign(:edition, edition())
    |> configure_stream_for_aggregate_fields()
    |> assign(:query, query)
    |> remote_ip()
    |> assign_new(:email, fn ->
      session["from"]
    end)
  end

  defp remote_ip(socket) do
    assign_new(socket, :client_ip, fn ->
      headers = get_connect_info(socket, :x_headers) || []

      RemoteIp.from(headers,
        proxies: {Dashboard.TrustedProxiesPlug, :trusted_proxies_remote_ip, []},
        clients: clients()
      )
    end)
  end

  defp authorized_services(socket, %{service: nil}) do
    with %{caveats: service_ids} <- socket.assigns,
         {:ok, services} <- Services.list_published(only: service_ids) do
      assign(socket, :services, services)
    end
  end

  defp authorized_services(socket, %{service: service}) do
    %{caveats: service_ids} = socket.assigns

    case Services.get_by_name(service, only: service_ids) do
      {:ok, service} ->
        Logger.debug(service: service)
        assign(socket, :services, List.wrap(service))

      :error ->
        assign(socket, :services, [])
    end
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
      version_b(stream)
    end)
  end

  def version_a(stream) do
    stream
    |> EventsRepo.merge_columns()
    |> Enum.to_list()
    |> then(fn [%{data: counts}, %{data: grouping_ids}, %{data: values}, %{data: maxes}] ->
      [counts, grouping_ids, values, maxes]
      |> Enum.zip_with(fn [count, grouping_id, value, max] ->
        aggregate(count: count, grouping_id: grouping_id, value: value, max: max)
      end)
      |> Enum.chunk_by(fn aggregate -> aggregate(aggregate, :grouping_id) end)
      |> Enum.map(fn [aggregate | _] = aggregates ->
        send(self(), {:aggregates, to_atom(aggregate(aggregate, :grouping_id)), aggregates})
        aggregate(aggregate, :grouping_id)
      end)
    end)
  end

  defp version_b(stream) do
    stream
    |> Stream.flat_map(fn [%{data: counts}, %{data: grouping_ids}, %{data: values}, %{data: maxs}] ->
      Enum.zip_with([counts, grouping_ids, values, maxs], fn [count, grouping_id, value, max] ->
        aggregate(count: count, grouping_id: grouping_id, value: value, max: max)
      end)
    end)
    |> Stream.chunk_by(fn aggregate -> aggregate(aggregate, :grouping_id) end)
    |> Enum.map(fn [aggregate | _] = aggregates ->
      send(self(), {:aggregates, to_atom(aggregate(aggregate, :grouping_id)), aggregates})
      aggregate(aggregate, :grouping_id)
    end)
  end

  def to_atom(grouping_id) do
    {:parameterized, {_, %{on_load: on_load}}} =
      Scouter.TypedAggregate.__schema__(:type, :grouping_id)

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
    case socket.assigns.services do
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
    |> Enum.reduce({nil, []}, fn
      # reject namespace because it's a path param
      {:service, path}, {_, params} -> {path, params}
      # reject nils
      {_k, nil}, {path, params} -> {path, params}
      # everything else is okay
      kv, {path, params} -> {path, [kv | params]}
    end)
  end

  defp patch(socket, %Query{} = query) do
    {path, query_params} = query_struct_to_query_params(query)

    request_uri =
      (path && ~p"/#{path}?#{query_params}") || ~p"/?#{query_params}"

    socket
    |> assign(:query, query)
    |> push_patch(to: request_uri)
  end

  defp dom_id(aggregate), do: "aggregate-#{Queryable.hash(aggregate)}"
  defp aggregate_fields, do: Aggregate.__schema__(:fields)

  embed_templates "stats_live_html/*", suffix: "_html"

  @impl true
  def render(%{services: []} = assigns) do
    four_oh_four_html(assigns)
  end

  @impl true
  def render(assigns) do
    index_html(assigns)
  end

  # allow 127.0.0.1 as client_ip when in development
  if Application.compile_env(:scouter, :dev_routes) do
    defp clients, do: ["127.0.0.1"]
  else
    defp clients, do: []
  end

  defp version do
    :scouter |> Application.spec(:vsn) |> to_string()
  end

  defp edition do
    Application.fetch_env!(:scouter, :edition)
  end

  defp fetch_aggregates(socket) when is_connected(socket) do
    query = socket.assigns.query
    filters = authorized_filters(query, socket.assigns.services)

    start_async(socket, :fetch_aggregates, fn ->
      Events.stream_aggregates(filters)
    end)
  end

  defp fetch_aggregates(socket), do: socket

  # lists all authorized services because nothing has been filtered
  defp authorized_filters(%{services: nil, service: nil} = query, authorized_services) do
    filters = Query.to_filters(query)

    services =
      Enum.map(authorized_services, fn domain ->
        TypeID.uuid(domain.id)
      end)

    Keyword.replace(filters, :services, services)
  end

  # return all authorized services, because none are filtered
  defp authorized_filters(%{service: nil, services: []} = query, authorized_services) do
    filters = Query.to_filters(query)

    services = Enum.map(authorized_services, &TypeID.uuid(&1.id))

    Keyword.replace(filters, :services, services)
  end

  # filter by sites because service is not present
  defp authorized_filters(%{service: nil} = query, authorized_services) do
    filters = Query.to_filters(query)

    services =
      Enum.reduce(authorized_services, [], fn authorized_service, acc ->
        if Scouter.Service.name(authorized_service) in query.services,
          do: [TypeID.uuid(authorized_service.id) | acc],
          else: acc
      end)

    Keyword.replace(filters, :services, services)
  end

  # filter for the single /:namespace, ignoring query[:service] because it has no effect when :service
  # is provided
  defp authorized_filters(%{service: service} = query, [authorized_service | []]) when not is_nil(service) do
    filters = Query.to_filters(query)

    Keyword.replace(filters, :services, [TypeID.uuid(authorized_service.id)])
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

  defp render_ip({_, _, _, _} = ip), do: :inet.ntoa(ip)
  defp render_ip({_, _, _, _, _, _, _, _} = ip), do: :inet.ntoa(ip)
  defp render_ip(nil), do: nil

  defp homepage do
    case System.fetch_env("HOMEPAGE") do
      {:ok, homepage} -> URI.parse(homepage)
      _ -> fallback_homepage()
    end
  end

  defp fallback_homepage do
    struct(URI, Dashboard.Endpoint.config(:url))
  end
end
