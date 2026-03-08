defmodule Scouter.Instances.Cacher do
  @moduledoc false
  use GenServer

  require Logger

  @impl GenServer
  def init(opts) do
    :ok = Phoenix.PubSub.subscribe(Scouter.PubSub, "service.created")
    :ok = Phoenix.PubSub.subscribe(Scouter.PubSub, "service.updated")
    :ok = Phoenix.PubSub.subscribe(Scouter.PubSub, "service.deleted")
    {:ok, Map.new(opts)}
  end

  @impl GenServer
  def handle_info({"service." <> _any = event, instance}, state) do
    Logger.metadata(instance: instance)
    Logger.info("handling #{event}")
    Scouter.Instances.clear_cache(instance)
    {:noreply, state}
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
end
