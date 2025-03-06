defmodule Dashboard.StatComponents do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: Dashboard.Gettext

  import Stats.Event, only: [aggregate: 2]
  import Stats.Events.GroupingID

  alias Dashboard.StatsLive.Query
  alias Stats.Queryable
  alias Stats.TypedAggregate

  require Logger

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

  def query(assigns) do
    ~H"""
    <.controls title="Scale" id="scale">
      <section class="has-[li]:block hidden">
        <h3>Operating Systems</h3>
        <ol>
          <li
            :for={filter <- Map.get(@query, :operating_systems) || []}
            class="hover:bg-zinc-200/70 flex flex-row justify-between hover:bg-zinc-200 group"
          >
            <span>{filter}</span>
            <label
              class="group-hover:bg-zinc-300 bg-zinc-200"
              for={input_id(group_id(:operating_system), filter)}
            >
              ╳
            </label>
          </li>
        </ol>
      </section>
      <section class="has-[li]:block hidden">
        <h3>Browsers</h3>
        <ol>
          <li :for={filter <- Map.get(@query, :browsers) || []}>
            <span>{filter}</span>
            <label for={input_id(group_id(:browser), filter)}>remove</label>
          </li>
        </ol>
      </section>

      <ol>
        <li :for={filter <- Map.get(@query, :operating_system_versions) || []}>
          <span>{gettext("OS ver. is %{value}", value: filter)}</span>
          <label for={input_id(group_id(:operating_system_version), filter)}>remove</label>
        </li>
        <li :for={filter <- Map.get(@query, :browser_versions) || []}>
          <span>{gettext("Browser ver. is %{value}", value: filter)}</span>
          <label for={input_id(group_id(:browser_version), filter)}>remove</label>
        </li>
        <li :for={filter <- Map.get(@query, :paths) || []}>
          <span>{gettext("Path is %{value}", value: filter)}</span>
          <label for={input_id(group_id(:path), filter)}>remove</label>
        </li>
        <li :for={filter <- Map.get(@query, :country_codes) || []}>
          <span>{gettext("Country is %{value}", value: filter)}</span>
          <label for={input_id(group_id(:country_code), filter)}>remove</label>
        </li>
        <li :for={filter <- Map.get(@query, :referrers) || []}>
          <span>{gettext("Referrer is %{value}", value: filter)}</span>
          <label for={input_id(group_id(:referrer), filter)}>remove</label>
        </li>
      </ol>
    </.controls>
    """
  end

  defp input_id(field, %TypedAggregate{} = typed_aggregate), do: "#{field}-#{Stats.Queryable.hash(typed_aggregate)}"
  defp input_id(group_id, value), do: Queryable.hash({group_id, value})

  slot :tab, doc: "Tabs" do
    attr :title, :string, required: true
    attr :field, :string, required: true
    attr :aggregates, :list, required: true, doc: "List of Stats.Aggregate"
    attr :filtered, :list, required: true
  end

  attr :class, :string, default: ""

  def tabbed_chart(assigns) do
    ~H"""
    <section class={@class} data-tabs class="grid grid-cols-1 grid-rows-[max-content_max-content]">
      <form>
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
      </form>
      <header class="flex flex-row gap-x-4">
        <h2 :for={tab <- @tab}><label for={tab.field}>{tab.title}</label></h2>
      </header>
      <section :for={tab <- @tab} data-tab class="hidden col-span-full row-start-2">
        <form method="GET" action="/" phx-change="filter">
          <ol id={"#{tab.field}-stream"} phx-update="stream" class="overflow-y-scroll h-[10lh]">
            <li :for={{dom_id, aggregate} <- tab.aggregates} id={dom_id}>
              <label class="flex flex-row items-center hover:bg-zinc-100">
                <input
                  type="checkbox"
                  class="hidden"
                  id={"#{Queryable.hash(aggregate)}"}
                  checked={is_aggregate_checked(Queryable.value(aggregate), tab.filtered)}
                  name={"#{tab.field}[]"}
                  value={Queryable.value(aggregate) || ""}
                />
                <span class="relative w-full">
                  <meter
                    min="0"
                    class="h-full w-full absolute inset-0 opacity-40 appearance-none"
                    value={Queryable.count(aggregate)}
                    max={aggregate(aggregate, :max)}
                  />
                  <span class="flex flex-row justify-between w-full pl-[1ch]">
                    <span>{Queryable.present(aggregate)}</span>
                    <span>{Queryable.count(aggregate)}</span>
                  </span>
                </span>
              </label>
            </li>
          </ol>
        </form>
      </section>
    </section>
    """
  end

  defp is_aggregate_checked(_, nil), do: false
  defp is_aggregate_checked(nil, filtered), do: "" in filtered
  defp is_aggregate_checked(value, filtered), do: value in filtered

  attr :query, Query, required: true

  def period(assigns) do
    ~H"""
    <.controls id="period" title="Period">
      <form method="GET" action="/" phx-change="limit">
        <fieldset :for={group <- Dashboard.StatsLive.Query.periods()} class="flex flex-col">
          <label
            :for={{label, value, hotkey} <- group}
            class="hover:bg-zinc-200/70 px-2 flex flex-row justify-between"
          >
            <div>
              <input
                data-controller="hotkey"
                data-hotkey={hotkey}
                checked={value == @query.interval}
                type="radio"
                name="interval"
                value={value}
              />
              <span>{label}</span>
            </div>
            <.hotkey keybind={hotkey} />
          </label>
          <.hr />
        </fieldset>
      </form>
    </.controls>
    """
  end

  attr :keybind, :string, required: true

  def hotkey(assigns) do
    ~H"""
    <span class="text-zinc-400">
      {@keybind}
    </span>
    """
  end

  attr :domains, :list

  def sites(assigns) do
    ~H"""
    <.controls id="sites" title="Sites">
      <form phx-change="filter" action="/" method="GET">
        <ul class="flex flex-col">
          <li :for={{domain, i} <- Enum.with_index(@domains, 1)} class="px-2 hover:bg-zinc-200/70">
            <label class="flex flex-row justify-between">
              <div>
                <input
                  data-controller="hotkey"
                  data-hotkey={i}
                  value={domain.host}
                  name="sites[]"
                  type="checkbox"
                />
                <span>{domain.host}</span>
              </div>
              <.hotkey keybind={i} />
            </label>
          </li>
        </ul>
      </form>
    </.controls>
    """
  end

  attr :action, :string, required: false
  attr :title, :string, required: true
  attr :id, :string, required: true

  slot :inner_block, required: true

  def controls(assigns) do
    ~H"""
    <fieldset id={@id} class="bg-zinc-100 shadow-[4px_5px_0px_0px_#] shadow-zinc-200">
      <legend class="bg-zinc-200 px-2 ml-2 mb-0.5">{@title}</legend>
      {render_slot(@inner_block)}
    </fieldset>
    """
  end

  attr :query, Query, required: true

  def scale(assigns) do
    ~H"""
    <.controls id="scale" title="Scale">
      <form action="/" method="GET" phx-change="scale">
        <label
          :for={{label, value, hotkey} <- Dashboard.StatsLive.Query.scale()}
          class="px-2 hover:bg-zinc-200/70 flex flex-row justify-between"
        >
          <div>
            <input
              data-controller="hotkey"
              data-hotkey={hotkey}
              checked={@query.scale == value}
              type="radio"
              name="scale"
              value={value}
            />
            <span>{gettext("%{label}", label: label)}</span>
          </div>
          <.hotkey keybind={hotkey} />
        </label>
      </form>
    </.controls>
    """
  end

  defp hr(assigns), do: ~H|<hr class="h-px my-[0.25lh] mx-2 border-0 bg-zinc-500/60" />|

  defp strftime(timestamp, :hh_mm), do: Calendar.strftime(timestamp, "%Y-%m-%d %H:%M")
end
