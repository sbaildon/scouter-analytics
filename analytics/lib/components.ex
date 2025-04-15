defmodule Components do
  @moduledoc false
  use Phoenix.Component

  attr :action, :string, required: false
  attr :title, :string, required: true
  attr :id, :string, required: true
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def controls(assigns) do
    ~H"""
    <fieldset id={@id} class={["bg-zinc-100 shadow-[4px_5px_0px_0px_#] shadow-zinc-200", @class]}>
      <legend class="tracking-[0.125ch] [text-rendering:optimizelegibility] uppercase bg-zinc-200 px-2 ml-2 mb-0.5">
        {@title}
      </legend>
      {render_slot(@inner_block)}
    </fieldset>
    """
  end

  slot :entry do
    attr :dt, :string
  end

  def dl(assigns) do
    ~H"""
    <dl class="flex flex-row gap-x-4 items-center py-0.5 px-1 w-max">
      <div :for={entry <- @entry} class="flex flex-row gap-x-1">
        <dt class="uppercase">{entry.dt}</dt>
        <dd>{render_slot(entry)}</dd>
      </div>
    </dl>
    """
  end
end
