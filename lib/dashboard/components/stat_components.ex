defmodule Dashboard.StatComponents do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: Dashboard.Gettext

  alias Dashboard.StatsLive.Query

  attr :title, :string, required: true
  attr :events, :list, required: true

  def timeline(assigns) do
    ~H"""
    <section>
      <table class="grid grid-cols-[max-content_max-content] gap-x-4">
        <caption class="col-span-full">{@title}</caption>
        <thead class="contents">
          <tr class="contents uppercase">
            <th>{gettext("Time")}</th>
            <th>{gettext("Count")}</th>
          </tr>
        </thead>
        <tbody class="contents">
          <tr :for={event <- @events} class="contents">
            <td>{strftime(event.period, :hh_mm)}</td>
            <td>{event.count}</td>
          </tr>
        </tbody>
      </table>
    </section>
    """
  end

  slot :tab, doc: "Tabs" do
    attr :title, :string, required: true
    attr :field, :string, required: true
    attr :aggregates, :list, required: true, doc: "List of Stats.Aggregate"
    attr :query, :list, required: true
    attr :value, :atom, required: false
  end

  attr :class, :string, default: ""

  def tabbed_chart(assigns) do
    ~H"""
    <form class={@class} method="GET" action="/" phx-change="filter">
      <fieldset data-tabs class="grid grid-cols-1 grid-rows-[max-content_max-content]">
        <input
          :for={{tab, index} <- Enum.with_index(@tab)}
          type="radio"
          name="tab"
          id={tab.field}
          value={tab.field}
          checked={index == 0}
          phx-update="ignore"
          class="hidden"
        />
        <legend class="flex flex-row gap-x-4">
          <label :for={tab <- @tab} for={tab.field}>{tab.title}</label>
        </legend>
        <fieldset :for={tab <- @tab} class="hidden col-span-full row-start-2">
          <ol id={"#{tab.field}-stream"} phx-update="stream">
            <li :for={{dom_id, aggregate} <- tab.aggregates} id={dom_id}>
              <label>
                <input
                  type="checkbox"
                  checked={is_aggregate_checked(aggregate, tab.value, tab.query)}
                  name={"#{tab.field}[]"}
                  value={Map.fetch!(aggregate, tab.value)}
                />
                <span>{Map.fetch!(aggregate, tab.value)}</span>
              </label>
            </li>
          </ol>
        </fieldset>
      </fieldset>
    </form>
    """
  end

  defp is_aggregate_checked(_, _, nil), do: false
  defp is_aggregate_checked(aggregate, field, filtered), do: Map.fetch!(aggregate, field) in filtered

  attr :query, Query, required: true

  def period(assigns) do
    ~H"""
    <form method="GET" action="/" phx-change="limit">
      <fieldset class="border border-zinc-600 pb-1 px-2">
        <legend class="px-1">Period</legend>
        <fieldset :for={group <- Dashboard.StatsLive.Query.periods()} class="flex flex-col">
          <label :for={{label, value} <- group}>
            <input checked={value == @query.interval} type="radio" name="interval" value={value} />
            <span>{label}</span>
          </label>
          <.hr />
        </fieldset>
      </fieldset>
    </form>
    """
  end

  attr :domains, :list

  def sites(assigns) do
    ~H"""
    <form method="GET" action="/" phx-change="filter">
      <fieldset class="border border-zinc-600 pb-1 px-2">
        <legend class="px-1">{gettext("Sites")}</legend>
        <ul class="flex flex-col">
          <li :for={domain <- @domains}>
            <label>
              <input value={domain.host} name="sites[]" type="checkbox" />
              <span>{domain.host}</span>
            </label>
          </li>
        </ul>
      </fieldset>
    </form>
    """
  end

  attr :query, Query, required: true

  def scale(assigns) do
    ~H"""
    <form id="scale" phx-update="ignore" method="GET" action="/" phx-change="scale">
      <fieldset class="border border-zinc-600 pb-1 px-2">
        <legend class="px-1">Scale</legend>
        <fieldset class="flex flex-col">
          <label :for={{label, value} <- Dashboard.StatsLive.Query.scale()}>
            <input checked={@query.scale == value} type="radio" name="scale" value={value} />
            <span>{gettext("%{label}", label: label)}</span>
          </label>
        </fieldset>
      </fieldset>
    </form>
    """
  end

  defp hr(assigns), do: ~H|<hr class="h-px my-[0.25lh] border-0 bg-zinc-500" />|

  defp strftime(timestamp, :hh_mm), do: Calendar.strftime(timestamp, "%Y-%m-%d %H:%M")
end
