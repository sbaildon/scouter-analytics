defmodule Identifier do
  @moduledoc false

  use Ecto.ParameterizedType

  @type t :: String.t()

  @impl true
  def init(opts) do
    schema = Keyword.fetch!(opts, :schema)
    field = Keyword.fetch!(opts, :field)

    case opts[:primary_key] do
      true ->
        prefix = Keyword.get(opts, :prefix) || raise "`:prefix` option is required"

        %{
          primary_key: true,
          schema: schema,
          prefix: prefix,
          dump_as: :raw
        }

      _any ->
        %{
          schema: schema,
          field: field,
          dump_as: :raw
        }
    end
  end

  @impl true
  def type(_params), do: :uuid

  @impl true
  def cast(nil, _params), do: {:ok, nil}

  def cast(data, params) do
    with {:ok, tid} <- TypeID.from_string(data),
         {:ok, prefix} <- {:ok, TypeID.prefix(tid)},
         {prefix, prefix} <- {prefix, prefix_for(params)} do
      {:ok, data}
    else
      _ -> :error
    end
  end

  @impl true
  def load(nil, _loader, _params), do: {:ok, nil}

  @impl true
  def load(data, _loader, params) do
    load_format(data, params)
  end

  defp load_format(base32, %{dump_as: :base32} = params) do
    TypeID.from(prefix_for(params), base32)
  end

  defp load_format(data, %{dump_as: :raw} = params) do
    with {:ok, tid} <- TypeID.from_uuid_bytes(prefix_for(params), data) do
      {:ok, TypeID.to_string(tid)}
    end
  end

  @impl true
  def dump(nil, _, _), do: {:ok, nil}

  @impl true
  def dump(id, _dumper, params) do
    dump_format(id, params)
  end

  defp dump_format(prefixed_id, %{dump_as: :base32}) do
    with {:ok, tid} <- TypeID.from_string(prefixed_id) do
      {:ok, TypeID.suffix(tid)}
    end
  end

  defp dump_format(prefixed_id, %{dump_as: :raw}) do
    with {:ok, tid} <- TypeID.from_string(prefixed_id),
         {:ok, suffix} <- {:ok, TypeID.suffix(tid)},
         {:ok, raw} <- TypeID.Base32.decode(suffix) do
      {:ok, {:blob, raw}}
    end
  end

  @impl true
  def autogenerate(params) do
    params
    |> prefix_for()
    |> TypeID.new()
    |> TypeID.to_string()
  end

  @spec generate(prefix :: String.t()) :: t()
  def generate(prefix) do
    prefix |> TypeID.new() |> TypeID.to_string()
  end

  @impl true
  def equal?(nil, nil, _prams), do: false

  @impl true
  def equal?(nil, _, _params), do: false

  @impl true
  def equal?(_, nil, _params), do: false

  @impl true
  def equal?(a, b, _params) do
    a = a |> TypeID.from_string!() |> TypeID.suffix()
    b = b |> TypeID.from_string!() |> TypeID.suffix()
    a == b
  end

  defp prefix_for(%{primary_key: true, prefix: prefix}), do: prefix

  # If we deal with a belongs_to assocation we need to fetch the prefix from
  # the associations schema module
  defp prefix_for(%{schema: schema, field: field}) do
    %{related: schema, related_key: field} = schema.__schema__(:association, field)
    {:parameterized, {__MODULE__, %{prefix: prefix}}} = schema.__schema__(:type, field)

    prefix
  end
end
