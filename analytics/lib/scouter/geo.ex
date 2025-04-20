defmodule Scouter.Geo do
  @moduledoc false
  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :database) do
      {:ok, path} when is_binary(path) ->
        children = [
          loader_child_spec(opts)
        ]

        Supervisor.init(children, strategy: :one_for_one)

      {:ok, nil} ->
        :ignore

      :error ->
        :ignore
    end
  end

  defp loader_child_spec(opts) do
    case Keyword.fetch!(opts, :database) do
      {:maxmind, _} = db ->
        maxmind_opts = Keyword.fetch!(opts, :maxmind_opts)
        :locus.loader_child_spec(:ipdb, db, maxmind_opts)

      path ->
        :locus.loader_child_spec(:ipdb, path)
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
