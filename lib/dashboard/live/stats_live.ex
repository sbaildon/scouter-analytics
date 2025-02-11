defmodule Dashboard.StatsLive do
  @moduledoc false
  use Dashboard, :live_view

  alias Stats.Domains
  alias Stats.Events

  @impl true
  def mount(_, _, socket) do
    hourly = IO.inspect(Events.hourly())

    events = IO.inspect(Events.retrieve())

    {:ok,
     socket
     |> assign(:domains, Domains.list())
     |> assign(:events, events)
     |> assign(:hourly, hourly), temporary_assigns: [hourly: [], events: []]}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:ok, query} = Dashboard.StatsLive.Query.validate(params)
    {:noreply, push_patch(socket, to: ~p"/?#{query}")}
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

  defmodule Query do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :sites, {:array, :string}
    end

    def validate(params) when is_map(params) do
      validate(%__MODULE__{}, params)
    end

    def validate(query, params) do
      query
      |> cast(params, [:sites])
      |> apply_action(:validate)
    end

    defimpl Phoenix.Param do
      def to_param(query) do
        query
        |> Map.from_struct()
        |> Map.reject(fn {_k, v} -> is_nil(v) end)
        |> Plug.Conn.Query.encode()
      end
    end
  end
end
