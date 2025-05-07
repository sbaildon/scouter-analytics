defmodule Scouter.Geo do
  @moduledoc false
  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, Map.new(init_arg), name: __MODULE__)
  end

  @impl true
  def init(opts) do
    case resolve_loader(opts) do
      {:ok, loader} ->
        Supervisor.init([loader], strategy: :one_for_one)

      :ignore ->
        Logger.info(msg: "no geoip database configured, geolocation service unavailable")
        :ignore
    end
  end

  defp resolve_loader(opts) do
    case opts do
      %{database_path: nil, maxmind: {nil, _}} ->
        :ignore

      %{maxmind: {api_key, edition}} when is_binary(api_key) ->
        cache_dir = Path.join([System.get_env("STATE_DIRECTORY"), "ipdb.mmdb.gz"])
        {:ok, :locus.loader_child_spec(:ipdb, {:maxmind, edition}, database_cache_file: cache_dir, license_key: api_key)}

      %{database_path: path} when is_binary(path) ->
        {:ok, :locus.loader_child_spec(:ipdb, path)}
    end
  end

  def lookup(ip) do
    case :locus.lookup(:ipdb, ip) do
      {:ok, result} ->
        {:ok, result}

      :not_found ->
        nil

      {:error, {:invalid_address, _address}} ->
        nil

      {:error, _reason} ->
        nil
    end
  end
end
