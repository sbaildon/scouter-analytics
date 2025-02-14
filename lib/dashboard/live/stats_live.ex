defmodule Dashboard.StatsLive do
  @moduledoc false
  use Dashboard, :live_view

  alias Dashboard.StatsLive.Query
  alias Stats.Domains
  alias Stats.Event
  alias Stats.Events
  alias Stats.EventsRepo
  alias Stats.SuperAggregate

  require Logger

  defp period(socket, query) do
    filters = Query.to_filters(query)

    scaled_events = Events.scale(query.scale, filters)

    assign(socket, :events, scaled_events)
  end

  defp super_aggregate(socket, query) do
    filters = Query.to_filters(query)

    start_async(socket, :fetch_super_aggregates, fn ->
      stream = Events.stream_super_aggregate(filters)
      stream
    end)
  end

  @impl true
  def mount(params, _, socket) do
    Plug.Conn.Query.encode(params)
    {:ok, query} = Query.validate(params)

    {:ok,
     socket
     |> then(fn socket ->
       Enum.reduce(Event.__schema__(:fields), socket, fn field, socket ->
         configure_aggregate_stream(socket, field)
       end)
     end)
     |> super_aggregate(query)
     |> assign(:query, query)
     |> assign(:domains, Domains.list()), temporary_assigns: [aggregates: []]}
  end

  defp configure_aggregate_stream(socket, key) do
    socket
    |> stream_configure(key, dom_id: &dom_id/1)
    |> stream(key, [], reset: true)
  end

  @impl true
  def handle_async(:fetch_super_aggregates, {:ok, stream}, socket) do
    {:ok, socket} =
      EventsRepo.transaction(fn ->
        stream
        |> Stream.chunk_by(& &1.grouping_id)
        |> Enum.reduce(socket, fn [aggregate | _] = aggregates, socket ->
          stream(socket, SuperAggregate.field(aggregate), aggregates, reset: true)
        end)
      end)

    {:noreply, socket}
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
        |> super_aggregate(query)
        |> period(query)

      _ ->
        socket
    end
  end

  embed_templates "stats_live_html/*", suffix: "_html"

  @impl true
  def render(assigns) do
    index_html(assigns)
  end

  defp patch(socket, query) do
    query_params =
      query
      |> Map.from_struct()
      |> Map.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.to_list()

    socket
    |> assign(:query, query)
    |> push_patch(to: ~p"/?#{query_params}")
  end

  defp dom_id(%SuperAggregate{} = super_aggregate), do: "super-aggregate-#{SuperAggregate.hash(super_aggregate)}"

  defmodule Period do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :from, :date
      field :to, :date
    end

    def changeset(period, params) do
      cast(period, params, [:from, :to])
    end
  end
end
