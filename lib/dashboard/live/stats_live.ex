defmodule Dashboard.StatsLive do
  @moduledoc false
  use Dashboard, :live_view

  alias Dashboard.StatsLive.Query
  alias Stats.Domains
  alias Stats.Events

  defp do_work(socket, query) do
    filters = Enum.to_list(Map.from_struct(query))
    path_aggregate = Events.retrieve(:path, filters)
    browser_aggregate = Events.retrieve(:browser, filters)
    browser_version_aggregate = Events.retrieve(:browser_version, filters)
    operating_system_aggregate = Events.retrieve(:operating_system, filters)
    operating_system_version_aggregate = Events.retrieve(:operating_system_version, filters)

    socket
    |> assign(:query, query)
    |> assign(:aggregates, %{
      paths: path_aggregate,
      browsers: browser_aggregate,
      browser_versions: browser_version_aggregate,
      operating_systems: operating_system_aggregate,
      operating_system_versions: operating_system_version_aggregate
    })
  end

  @impl true
  def mount(params, _, socket) do
    hourly = Events.hourly()

    params |> Plug.Conn.Query.encode() |> IO.inspect()

    {:ok, query} = params |> Query.validate() |> IO.inspect()

    {:ok,
     socket
     |> assign(:domains, Domains.list())
     |> do_work(query)
     |> assign(:hourly, hourly), temporary_assigns: [hourly: [], aggregate: []]}
  end

  @impl true
  def handle_event("filter", %{"_target" => [target | []]} = params, socket) do
    %{query: existing_query} = socket.assigns
    proposed_query = Map.put_new(params, target, [])

    {:ok, query} = Query.validate(existing_query, proposed_query)

    {:noreply,
     socket
     |> do_work(query)
     |> assign(:query, query)
     |> patch(query)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _, _params) do
    socket
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

    push_patch(socket, to: ~p"/?#{query_params}")
  end

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
