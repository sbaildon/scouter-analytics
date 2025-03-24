defmodule Ecto.URI do
  @moduledoc false
  use Ecto.Type

  def type, do: :string

  # Provide custom casting rules.
  # Cast strings into the URI struct to be used at runtime
  def cast(uri) when is_binary(uri) do
    {:ok, URI.parse(uri)}
  end

  # Accept casting of URI structs as well
  def cast(%URI{} = uri), do: {:ok, uri}

  # Everything else is a failure though
  def cast(_), do: :error

  # When loading data from the database, as long as it's a map,
  # we just put the data back into a URI struct to be stored in
  # the loaded schema struct.
  def load(data) do
    URI.new(data)
  end

  # When dumping data to the database, we *expect* a URI struct
  # but any value could be inserted into the schema struct at runtime,
  # so we need to guard against them.
  def dump(%URI{} = uri), do: {:ok, URI.to_string(uri)}
  def dump(_), do: :error

  defimpl Jason.Encoder do
    def encode(uri, opts) do
      uri
      |> URI.to_string()
      |> Jason.Encode.string(opts)
    end
  end
end
