defmodule Ecto.Regex do
  use Ecto.Type

  def type, do: :string

  def cast(term) do
    Regex.compile(term)
  end

  def dump(regex) do
    {:ok, Regex.source(regex)}
  end

  def load(data) do
    Regex.compile(data)
  end

  def equal?(one, two), do: one == two
end
