defmodule Dashboard.StatsLive do
  @moduledoc false
  use Dashboard, :live_view

  alias Dashboard.StatsLive.Query
  alias Stats.Domains
  alias Stats.Events

  require Logger

  defp period(socket, query) do
    filters = Query.to_filters(query)

    scaled_events = Events.scale(query.scale, filters)

    assign(socket, :events, scaled_events)
  end

  defp aggregates(socket, query) do
    filters = Query.to_filters(query)

    path_aggregate = Events.retrieve(:path, filters)
    browser_aggregate = Events.retrieve(:browser, filters)
    browser_version_aggregate = Events.retrieve(:browser_version, filters)
    operating_system_aggregate = Events.retrieve(:operating_system, filters)
    operating_system_version_aggregate = Events.retrieve(:operating_system_version, filters)
    referrer_aggregate = Events.retrieve(:referrer, filters)
    utm_source_aggregate = Events.retrieve(:utm_source, filters)
    utm_campaign_aggregate = Events.retrieve(:utm_campaign, filters)
    utm_medium_aggregate = Events.retrieve(:utm_medium, filters)
    utm_content_aggregate = Events.retrieve(:utm_content, filters)
    utm_term_aggregate = Events.retrieve(:utm_term, filters)
    country_code_aggregate = Events.retrieve(:country_code, filters)

    assign(socket, :aggregates, %{
      paths: path_aggregate,
      browsers: browser_aggregate,
      browser_versions: browser_version_aggregate,
      operating_systems: operating_system_aggregate,
      operating_system_versions: operating_system_version_aggregate,
      referrers: referrer_aggregate,
      utm_sources: utm_source_aggregate,
      utm_campaigns: utm_campaign_aggregate,
      utm_mediums: utm_medium_aggregate,
      utm_contents: utm_content_aggregate,
      utm_terms: utm_term_aggregate,
      country_codes: country_code_aggregate
    })
  end

  @impl true
  def mount(params, _, socket) do
    Plug.Conn.Query.encode(params)
    {:ok, query} = Query.validate(params)

    {:ok,
     socket
     |> assign(:query, query)
     |> assign(:domains, Domains.list()), temporary_assigns: [hourly: [], aggregate: []]}
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
        socket |> period(query) |> aggregates(query)

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
