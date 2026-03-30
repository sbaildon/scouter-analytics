defmodule Scouter.Signals do
  @moduledoc false
  use GenServer

  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    System.trap_signal(:sighup, :config_reload, fn ->
      Logger.info("trapped sighup")
      :ok
    end)

    {:ok, %{}}
  end
end
