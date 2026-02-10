defmodule Ecto.JSON do
  use Ecto.Type

  def type, do: :map

  def cast(data) when is_map(data) do
    {:ok, JSON.encode_to_iodata!(data)}
  end

  def load(data) do
    JSON.decode(data)
  end

  def dump(data) when is_map(data) do
    {:ok, JSON.encode_to_iodata!(data)}
  end
end
