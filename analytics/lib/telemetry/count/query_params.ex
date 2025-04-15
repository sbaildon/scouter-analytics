defmodule Telemetry.Count.QueryParams do
  @moduledoc false
  use Ecto.Type

  def type, do: :map

  def cast("?" <> query) do
    cast(query)
  end

  def cast(query) when is_binary(query) do
    {:ok, URI.decode_query(query, %{}, :rfc3986)}
  end

  def load(data), do: {:ok, data}

  def dump(%{} = query), do: {:ok, query}
  def dump(_), do: :error
end
