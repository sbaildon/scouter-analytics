defmodule Scouter.Writer do
  @moduledoc false
  use GenServer

  alias Scouter.Repo

  @impl GenServer
  def init(opts), do: {:ok, opts}

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def insert(queryable, opts \\ []) do
    GenServer.call(__MODULE__, {:insert, queryable, opts})
  end

  def transact(multi, opts \\ []) do
    GenServer.call(__MODULE__, {:transact, multi, opts})
  end

  def transaction(multi, opts \\ []) do
    GenServer.call(__MODULE__, {:transact, multi, opts})
  end

  @impl GenServer
  def handle_call({:transact, multi, opts}, _from, state) do
    {:reply, Repo.transact(multi, opts), state}
  end

  @impl GenServer
  def handle_call({:insert, queryable, opts}, _from, state) do
    {:reply, Repo.insert(queryable, opts), state}
  end
end
