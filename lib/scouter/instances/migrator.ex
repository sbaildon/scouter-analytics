defmodule Scouter.Instances.Migrator do
  @moduledoc false
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    with {naming_scheme, opts} <- Keyword.pop(opts, :process),
         repo_pid <- lookup(naming_scheme) do
      Ecto.Migrator.init([{:dynamic_repo, repo_pid} | opts])
    end
  end

  defp lookup({:via, :global, name}) do
    :global.whereis_name(name)
  end

  defp lookup({:global, name}) do
    :global.whereis_name(name)
  end

  defp lookup({:via, registry, name}) do
    apply(registry, :lookup, [name])
  end
end
