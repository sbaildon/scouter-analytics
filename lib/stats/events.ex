defmodule Stats.Events do
  @moduledoc false
  use Agent

  alias Stats.Event
  alias Stats.EventsRepo

  def start_link(_) do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def retrieve(_) do
    EventsRepo.all(Event)
  end

  def record(event) do
    Agent.get(__MODULE__, &record(&1, event))
  end

  def record(_context, %Event{} = event) do
    for _i <- 1..10 do
      Stats.EventsRepo.insert(%{event | site_id: TypeID.new("site")})
    end
  end
