defmodule Dashboard.StatsLive do
  @moduledoc false
  use Dashboard, :live_view

  import Stats.Event, only: [aggregate: 1, aggregate: 2]

  alias Dashboard.StatsLive.Query
  alias Stats.Aggregate
  alias Stats.Domains
  alias Stats.Events
  alias Stats.EventsRepo
  alias Stats.Queryable

  require Logger

    filters = Query.to_filters(query)
  defmacro is_connected(socket) do
    quote do
      unquote(socket).transport_pid != nil
    end
  end

    scaled_events = Events.scale(query.scale, filters)
  defp period(socket, _query) do

    assign(socket, :events, scaled_events)
  end


  defp fetch_aggregates(socket, query) when is_connected(socket) do
    filters = Query.to_filters(query)

    start_async(socket, :fetch_aggregates, fn ->
      stream = Events.stream_aggregates(filters)
      stream
    end)
  end

  defp fetch_aggregates(socket, _query), do: socket

  @impl true
  def mount(params, _, socket) do
    {:ok, query} = Query.validate(params)

    {:ok,
     socket
     |> configure_stream_for_aggregate_fields()
     |> fetch_aggregates(query)
     |> assign(:query, query)
     |> then(fn socket ->
       headers = get_connect_info(socket, :x_headers) || []
       ip = RemoteIp.from(headers, clients: clients())
       assign(socket, :client_ip, :inet.ntoa(ip))
     end)
     |> assign(:domains, Domains.list())}
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
    stream |> update_aggregate_streams() |> post_handle_async(socket)
  end

  defp post_handle_async({:ok, []}, socket) do
    {:noreply, stream_empty_aggregates(socket)}
  end

  defp post_handle_async({:ok, _}, socket) do
    {:noreply, socket}
  end

  defp stream_empty_aggregates(socket), do: Enum.reduce(aggregate_fields(), socket, &stream(&2, &1, [], reset: true))

  @impl true
  def handle_info({:aggregates, field, aggregates}, socket) do
    {:noreply, stream(socket, field, aggregates, reset: true)}
  end

  def handle_event("scale", params, socket) do
    %{query: existing_query} = socket.assigns

    {:ok, query} = Query.validate(existing_query, params)

    {:noreply, patch(socket, query)}
  end

  def handle_event("limit", params, socket) do
    %{query: existing_query} = socket.assigns

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
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _, params) do
    %{query: existing_query} = socket.assigns

    case Query.validate(existing_query, params) do
      {:ok, query} ->
        socket
        |> fetch_aggregates(query)
        |> period(query)

      _ ->
        socket
    end
  end

  defp patch(socket, %Query{} = query) do
    query_params =
      query
      |> Map.from_struct()
      |> Map.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.to_list()

    socket
    |> assign(:query, query)
    |> push_patch(to: ~p"/?#{query_params}")
  end

  defp dom_id(aggregate), do: "aggregate-#{Queryable.hash(aggregate)}"
  defp aggregate_fields, do: Aggregate.__schema__(:fields)

  embed_templates "stats_live_html/*", suffix: "_html"

  @impl true
  def render(assigns) do
    index_html(assigns)
  end

  if Application.compile_env(:stats, :dev_routes) do
    defp clients, do: ["127.0.0.1"]
  else
    defp clients, do: []
  end
end
