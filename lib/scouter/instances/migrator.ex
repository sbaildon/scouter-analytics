defmodule Scouter.Instances.Migrator do
  @moduledoc false
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    with {{registry, key}, opts} <- Keyword.pop(opts, :process),
         [{repo, _}] <- Registry.lookup(registry, key) do
      Ecto.Migrator.init([{:dynamic_repo, repo} | opts])
    end
  end
end
