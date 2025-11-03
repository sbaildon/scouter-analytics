defmodule Ecto.Regex do
  @moduledoc false
  use Ecto.Type

  def type, do: :string

  def cast(term) do
    Regex.compile(term, [:anchored, :caseless, :never_utf])
  end

  def dump(regex) do
    {:ok, Regex.source(regex)}
  end

  def load(data) do
    Regex.compile(data, [:anchored, :caseless, :never_utf])
  end

  def equal?(one, two), do: one == two
end
