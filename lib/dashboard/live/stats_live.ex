defmodule Dashboard.StatsLive do
  @moduledoc false
  use Dashboard, :live_view

  import Scouter.Events.GroupingID

  alias Dashboard.RateLimit
  alias Dashboard.StatsLive.Query
  alias Scouter.Services

  require Logger

  @impl true
  def mount(_params, session, socket) do
    {:ok, handle_mount(socket.assigns.live_action, session, socket)}
  end

  def handle_mount(_live_action, session, socket) do
    {:ok, query} =
      socket.private
      |> get_in([:connect_params, "query"])
      |> parse_query()
      |> Query.validate()

    socket
    |> authorized_services()
    |> assign(:version, version())
    |> assign(:query, query)
    |> remote_ip()
    |> assign_new(:email, fn ->
      session["from"]
    end)
    |> fetch_aggregates()
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

  defp authorized_services(socket) do
    with %{caveats: [{instance, service_ids}]} <- socket.assigns,
         {:ok, services} <- Services.list_published(instance, ids: service_ids) do
      assign(socket, :services, services)
    end
  end

  @impl true
  def handle_async(:fetch_aggregates, {:ok, dataframes}, socket) do
    [{_pid, channel_pid}] = Registry.lookup(Dashboard.ArrowChannelRegistry, :erlang.phash2(socket.transport_pid))

    GenServer.cast(channel_pid, {:push, dataframes})

    {:noreply, socket}
  end

  @impl true
  def handle_info(:fetch_aggregates, socket) do
    {:noreply, fetch_aggregates(socket)}
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
  def handle_event("filter", %{"group" => group, "value" => value}, socket) do
    %{query: existing_query} = socket.assigns

    {:ok, query} = Query.validate(existing_query, %{group => List.wrap(value)})

    {:noreply, patch(socket, query)}
  end

  @impl true
  def handle_event("unfilter", %{"group" => group, "value" => value}, socket) do
    %{query: existing_query} = socket.assigns

    dropped = existing_query |> Map.fetch!(String.to_existing_atom(group)) |> List.delete(value)

    {:ok, query} = Query.validate(existing_query, %{group => dropped})

    {:noreply, patch(socket, query)}
  end

  @impl true
  def handle_event("filter", %{"_target" => [target | []]} = params, socket) do
    %{query: existing_query} = socket.assigns
    proposed_query = Map.put_new(params, target, [])

    {:ok, query} = Query.validate(existing_query, proposed_query)

    {:noreply, patch(socket, query)}
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
    {_path, query_params} = query_struct_to_query_params(query)

    socket
    |> assign(:query, query)
    |> push_event("query", Map.new(query_params))
    |> fetch_aggregates()
  end

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

  def fetch_aggregates(socket) when is_connected(socket) do
    %{query: query, caveats: [{instance, _}]} = socket.assigns

    filters = authorized_filters(query, socket.assigns.services)

    key = socket.id
    scale = to_timeout(millisecond: 750)
    limit = 1

    case RateLimit.hit(key, scale, limit) do
      {:allow, _current_count} ->
        start_async(socket, :fetch_aggregates, fn ->
          Scouter.Events.arrow(instance, filters)
        end)

      {:deny, ms_until_next_window} ->
        Process.send_after(self(), :fetch_aggregates, ms_until_next_window)
        socket
    end
  end

  def fetch_aggregates(socket), do: socket

  # lists all authorized services because nothing has been filtered
  defp authorized_filters(%{services: nil, service: nil} = query, authorized_services) do
    filters = Query.to_filters(query)

    services =
      Enum.map(authorized_services, fn domain ->
        Identifier.uuid(domain.id)
      end)

    Keyword.replace(filters, :services, services)
  end

  # return all authorized services, because none are filtered
  defp authorized_filters(%{service: nil, services: []} = query, authorized_services) do
    filters = Query.to_filters(query)

    services = Enum.map(authorized_services, &Identifier.uuid(&1.id))

    Keyword.replace(filters, :services, services)
  end

  # filter by sites because service is not present
  defp authorized_filters(%{service: nil} = query, authorized_services) do
    filters = Query.to_filters(query)

    services =
      Enum.reduce(authorized_services, [], fn authorized_service, acc ->
        if authorized_service.id in query.services,
          do: [Identifier.uuid(authorized_service.id) | acc],
          else: acc
      end)

    Keyword.replace(filters, :services, services)
  end

  # filter for the single /:namespace, ignoring query[:service] because it has no effect when :service
  # is provided
  defp authorized_filters(%{service: service} = query, [authorized_service | []]) when not is_nil(service) do
    filters = Query.to_filters(query)

    Keyword.replace(filters, :services, [Identifier.uuid(authorized_service.id)])
  end

  defp authorized_filters(_, _), do: []

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

  defp parse_query(nil), do: parse_query("")

  defp parse_query(query_string) do
    query_string
    |> URI.query_decoder(:rfc3986)
    |> Enum.reduce(%{}, fn
      {key, value}, acc when key in ["interval", "from", "to", "service"] -> Map.put(acc, key, value)
      {key, value}, acc -> Map.update(acc, key, [value], fn values -> [value | values] end)
    end)
  end
end
