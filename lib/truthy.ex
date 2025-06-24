defmodule Truthy do
  @moduledoc false

  def cast("false"), do: false
  def cast("no"), do: false
  def cast("0"), do: false
  def cast(0), do: false
  def cast(nil), do: false

  def cast("true"), do: true
  def cast("yes"), do: true
  def cast("1"), do: true
  def cast(1), do: true

  def cast(other) do
    raise "expected a truthy value: 1/0, yes/no, true/false, found #{inspect(other)}"
  end

  def get_env(name, fallback \\ nil) do
    name
    |> System.get_env(fallback)
    |> cast()
  end
end
