defmodule Telemetry.Count.Path do
  @moduledoc false
  use Ecto.Type

  def type, do: :string

  def cast(path) when is_binary(path) do
    case new(path) do
      {:ok, %{path: path}} -> {:ok, normalize(path)}
      _ -> :error
    end
  end

  def cast(_), do: :error

  def load(data), do: {:ok, data}

  def dump(path), do: {:ok, path}

  defp new(path) do
    path |> URI.parse() |> URI.new()
  end

  defp normalize("/" <> _ = path), do: path
  defp normalize(path), do: "/" <> path
end
