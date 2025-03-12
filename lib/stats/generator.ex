defmodule Stats.Generator do
  @moduledoc false
  use GenServer

  alias Stats.Event
  alias Stats.Events

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, opts, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    Process.send_after(self(), :periodic, 1000)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:periodic, state) do
    do_work()
    Process.send_after(self(), :periodic, period_ms())

    {:noreply, state}
  end

  defp do_work do
    now = NaiveDateTime.utc_now()

    events =
      for _i <- 1..Enum.random(20..200) do
        %Event{
          timestamp: now
        }
        |> Events.Mock.add_site_and_host()
        |> Events.Mock.add_country_details()
        |> Events.Mock.add_utm_parameters()
        |> Events.Mock.add_os_and_browser_details()
        |> Events.Mock.add_path()
        |> Events.Mock.add_referrer()
      end

    Events.record(events)
  end

  defp period_ms, do: 50_000
end
