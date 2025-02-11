defmodule Dashboard.StatComponents do
  @moduledoc false
  use Phoenix.Component

  attr :title, :string, required: true
  attr :events, :list, required: true

  def timeline(assigns) do
    ~H"""
    <section>
      <table class="grid grid-cols-[max-content_max-content] gap-x-4">
        <caption class="col-span-full">{@title}</caption>
        <thead class="contents">
          <tr class="contents uppercase">
            <th>Time</th>
            <th>Count</th>
          </tr>
        </thead>
        <tbody class="contents">
          <tr :for={event <- @events} class="contents">
            <td>{strftime(event.hour, :hh_mm)}</td>
            <td>{event.count}</td>
          </tr>
        </tbody>
      </table>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :events, :list, required: true

  def bar_chart(assigns) do
    ~H"""
    <section>
      <table class="grid grid-cols-[max-content_max-content] gap-x-4">
        <caption class="col-span-full">{@title}</caption>
        <thead class="contents">
          <tr class="contents uppercase">
            <th>Path</th>
            <th>Count</th>
          </tr>
        </thead>
        <tbody class="contents">
          <tr :for={{count, path} <- @events} class="contents">
            <td>{path}</td>
            <td>{count}</td>
          </tr>
        </tbody>
      </table>
    </section>
    """
  end

  defp strftime(timestamp, :hh_mm), do: Calendar.strftime(timestamp, "%H:%M")
end
