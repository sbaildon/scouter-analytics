defmodule Scouter.Writer do
  @moduledoc false
  use GenServer

  alias Scouter.Repo

  @impl GenServer
  def init(opts), do: {:ok, opts}

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def insert(queryable) do
    GenServer.call(__MODULE__, {:insert, queryable})
  end

  def transaction(multi) do
    GenServer.call(__MODULE__, {:transaction, multi})
  end

  @impl GenServer
  def handle_call({:transaction, multi}, _from, state) do
    {:reply, Repo.transaction(multi), state}
  end

  @impl GenServer
  def handle_call({:insert, queryable}, _from, state) do
    {:reply, Repo.insert(queryable), state}
  end
end
