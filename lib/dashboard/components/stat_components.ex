defmodule Dashboard.StatComponents do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: Dashboard.Gettext

  import Stats.Event, only: [aggregate: 1, aggregate: 2]
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

  defp filters do
    [
      {:browsers, group_id(:browser), "Browsers"},
      {:browser_versions, group_id(:browser_version), "Browser Vers."},
      {:operating_systems, group_id(:operating_system), "Operating Systems"},
      {:operating_system_versions, group_id(:operating_system_version), "Operating System Vers."},
      {:paths, group_id(:path), "Paths"},
      {:referrers, group_id(:referrer), "Referrers"},
      {:utm_mediums, group_id(:utm_medium), "UTM Mediums"},
      {:utm_sources, group_id(:utm_source), "UTM Sources"},
      {:utm_contents, group_id(:utm_content), "UTM Content"},
      {:utm_campaigns, group_id(:utm_campaign), "UTM Campaigns"},
      {:utm_terms, group_id(:utm_term), "UTM Terms"},
      {:country_codes, group_id(:country_code), "Countries"}
    ]
  end

  def filters(assigns) do
    ~H"""
    <.controls title="Filters" id="filers" class="hidden has-[li]:block">
      <section
        :for={{param, group_id, title} <- filters()}
        :if={Map.get(@query, param)}
        class="has-[li]:block hidden last-of-type:pb-1.25"
      >
        <h3 class="px-2">{title}</h3>
        <ol>
          <li
            :for={filter <- Map.get(@query, param) || []}
            class="before:text-zinc-500/60 last-of-type:before:content-['└─'] before:content-['├─'] gap-x-[1ch] px-2 items-center hover:bg-zinc-200/70 flex flex-row hover:bg-zinc-200"
          >
            <span class="grow">
              {Queryable.present(aggregate(grouping_id: group_id, value: filter))}
            </span>
            <label class="group" for={input_id(group_id, filter)}>
              <span class="tracking-[0.2ch] text-xs group-hover:border-black group-hover:bg-black group-hover:text-white border border-zinc-300 shadow-[2px_2px_0px_0px] shadow-zinc-400/40 bg-zinc-50 uppercase px-1.5">
                remove
              </span>
            </label>
          </li>
        </ol>
      </section>
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
    attr :hotkey, :string, required: false
  end

  attr :class, :string, default: ""

  def tabbed_chart(assigns) do
    ~H"""
    <section class={@class} data-tabs class="grid grid-cols-1 grid-rows-[max-content_max-content]">
      <form>
        <header class="bg-transparent flex flex-row">
          <h2 :for={{tab, index} <- Enum.with_index(@tab)} class="bg-zinc-200">
            <label>
              <span class="px-2 uppercase tracking-[0.075em]">{tab.title}</span>
              <input
                type="radio"
                name="tab"
                data-controller="hotkey"
                data-hotkey={Map.get(tab, :hotkey)}
                id={tab.field}
                value={tab.field}
                checked={index == 0}
                phx-update="ignore"
                class="hidden"
              />
            </label>
          </h2>
        </header>
      </form>
      <section :for={tab <- @tab} data-tab class="pt-[1ch] hidden col-span-full row-start-2">
        <form method="GET" action="/" phx-change="filter">
          <ol
            id={"#{tab.field}-stream"}
            phx-update="stream"
            class="overflow-y-scroll snap-y snap-mandatory h-[10lh]"
          >
            <li :for={{dom_id, aggregate} <- tab.aggregates} id={dom_id} class="snap-start">
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
                  <span class="flex flex-row justify-between w-full px-[1ch]">
                    <span>{Queryable.present(aggregate)}</span>
                    <span>{display_aggregate_count(aggregate)}</span>
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

  defp display_aggregate_count(aggregate) do
    {:ok, formatted} =
      aggregate
      |> Queryable.count()
      |> then(fn count ->
        if count >= 100_000 do
          Stats.Cldr.Number.to_string(count, format: :short)
        else
          {:ok, count}
        end
      end)

    formatted
  end

  defp is_aggregate_checked(_, nil), do: false
  defp is_aggregate_checked(nil, filtered), do: "" in filtered
  defp is_aggregate_checked(value, filtered), do: value in filtered

  attr :query, Query, required: true

  def period(assigns) do
    ~H"""
    <.controls id="period" title="Period">
      <form method="GET" action="/" phx-change="limit">
        <.intersperse :let={group} enum={Dashboard.StatsLive.Query.periods()}>
          <:separator>
            <.hr />
          </:separator>
          <fieldset class="last:pb-1.25 flex flex-col">
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
          </fieldset>
        </.intersperse>
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
  attr :query, Query

  def sites(%{domains: [_ | []]} = assigns) do
    ~H"""
    <.controls id="sites" title={gettext("Site")}>
      <form phx-change="filter" action="/" method="GET">
        <ul class="flex flex-col pb-1.25">
          <li :for={domain <- @domains} class="px-2">
            <span class="flex flex-row justify-between">
              <span>{domain.host}</span>
            </span>
          </li>
        </ul>
      </form>
    </.controls>
    """
  end

  def sites(assigns) do
    ~H"""
    <.controls id="sites" title={gettext("Sites")}>
      <form phx-change="filter" action="/" method="GET">
        <ul class="flex flex-col pb-1.25">
          <li :for={{domain, i} <- Enum.with_index(@domains, 1)} class="px-2 hover:bg-zinc-200/70">
            <label class="flex flex-row justify-between">
              <div>
                <input
                  data-controller="hotkey"
                  data-hotkey={i}
                  value={domain.host}
                  name="sites[]"
                  type="checkbox"
                  checked={domain.host in (@query.sites || [])}
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
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def controls(assigns) do
    ~H"""
    <fieldset id={@id} class={["bg-zinc-100 shadow-[4px_5px_0px_0px_#] shadow-zinc-200", @class]}>
      <legend class="bg-zinc-200 px-2 ml-2 mb-0.5">{@title}</legend>
      {render_slot(@inner_block)}
    </fieldset>
    """
  end

  attr :query, Query, required: true

  def scale(assigns) do
    ~H"""
    <.controls id="scale" title="Scale">
      <form
        action="/"
        method="GET"
        phx-change="scale"
        class="grid grid-cols-2 gap-x-[0.5ch] grid-flow-col grid-rows-3"
      >
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

  defp hr(assigns), do: ~H|<hr class="h-px my-[calc(0.5em-0.5px)] mx-2 border-0 bg-zinc-500/60" />|

  defp strftime(timestamp, :hh_mm), do: Calendar.strftime(timestamp, "%Y-%m-%d %H:%M")
end
