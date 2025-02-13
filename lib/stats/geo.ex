defmodule Stats.Geo do
  @moduledoc false
  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    database = opts[:database]
    license_key = opts[:license_key]

    children = [
      :locus.loader_child_spec(:ipdb, database, license_key: license_key)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def lookup(ip) do
    case :locus.lookup(:ipdb, ip) do
      {:ok, result} ->
        result

      :not_found ->
        nil

      {:error, {:invalid_address, _address}} ->
        nil

      {:error, reason} ->
        Logger.warning(reason)
        nil
    end
  end
end
