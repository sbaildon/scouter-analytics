defmodule Identifier do
  @moduledoc false
  use Ecto.ParameterizedType

  @type t :: String.t()

  def uuid(id) do
    with {:ok, tid} <- TypeID.from_string(id), do: TypeID.uuid(tid)
  end

  def new(prefix, opts \\ []) do
    prefix
    |> TypeID.new(opts)
    |> to_string()
  end

  def cast(nil, _params), do: {:ok, nil}

  def cast(id, _params) do
    {:ok, id}
  end

  def dump(nil, _dumper, _params), do: {:ok, nil}

  def dump(id, _dumper, %{type: type} = params) do
    {:ok, tid} = TypeID.from_string(id)
    prefix = find_prefix(params)

    case {tid.prefix, type} do
      {^prefix, :string} -> {:ok, TypeID.to_string(tid)}
      {^prefix, :uuid} -> {:ok, TypeID.uuid_bytes(tid)}
      _ -> :error
    end
  end

  def load(id, loader, params) do
    with {:ok, type_id} <- TypeID.Ecto.load(id, loader, params),
         do: {:ok, TypeID.to_string(type_id)}
  end

  def autogenerate(params), do: params |> TypeID.Ecto.autogenerate() |> TypeID.to_string()

  def equal?(one, two, _params), do: one == two

  defdelegate init(opts), to: TypeID
  defdelegate type(id), to: TypeID

  defdelegate embed_as(format, params), to: TypeID

  defp find_prefix(%{prefix: prefix}) when not is_nil(prefix), do: prefix

  defp find_prefix(%{schema: schema, field: field}) do
    %{related: schema, related_key: field} = schema.__schema__(:association, field)

    prefix =
      case schema.__schema__(:type, field) do
        {:parameterized, {Identifier, %{prefix: prefix}}} -> prefix
        {:parameterized, Identifier, %{prefix: prefix}} -> prefix
        _ -> nil
      end

    prefix
  end
end
