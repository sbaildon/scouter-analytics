defmodule Telemetry.Sink do
  @moduledoc false
  use GenStage

  require Logger

  @impl GenStage
  def init(opts) do
    {events, _opts} = Keyword.pop(opts, :events, [])

    pending_demand = 0
    buffer_size = length(events)

    {:producer, {events, buffer_size, pending_demand}}
  end

  defp dispatch_events(events, buffer_size, total_demand) do
    case Decimal.compare(buffer_size, total_demand) do
      # demand is exactly our queue size
      :eq ->
        {:noreply, events, {[], 0, 0}}

      # we don't have enough events to satisfy demands
      :lt ->
        remaining_demand = total_demand - length(events)
        {:noreply, events, {[], 0, remaining_demand}}

      # we have more events than the processor can handle
      :gt ->
        {demanded, remaining} = Enum.split(events, total_demand)
        {:noreply, demanded, {remaining, length(remaining), 0}}
    end
  end

  @impl GenStage
  def handle_demand(demand, {events, buffer_size, pending_demand}) do
    dispatch_events(events, buffer_size, demand + pending_demand)
  end

  @impl GenStage
  def handle_cast({:push, params, headers}, {events, buffer_size, pending_demand}) do
    event = build_event(params, headers)
    events = [event | events]

    dispatch_events(events, buffer_size, pending_demand)
  end

  def push(params, headers) do
    Telemetry.Broadway
    |> Broadway.producer_names()
    |> Enum.random()
    |> GenStage.cast({:push, params, headers})
  end

  defp build_event(params, headers) do
    {params, headers}
  end
end
