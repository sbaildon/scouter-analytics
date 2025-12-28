defmodule Scouter.Instances.Migrator do
  @moduledoc false
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    with {naming_scheme, opts} <- Keyword.pop(opts, :process) do
      repo_pid = lookup(naming_scheme)
      Ecto.Migrator.init([{:dynamic_repo, repo_pid} | opts])
    end
  end

  defp lookup({:via, :global, name}) do
    :global.whereis_name(name)
  end

  defp lookup({:global, name}) do
    :global.whereis_name(name)
  end

  defp lookup({:via, mod, {registry, key}}) do
    [{pid, _}] = apply(mod, :lookup, [registry, key])
    pid
  end
end
