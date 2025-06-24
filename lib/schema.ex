defmodule Schema do
  @moduledoc false
  defmacro __using__(opts) do
    prefix = Keyword.fetch!(opts, :prefix)

    quote do
      use Ecto.Schema

      import Ecto.Changeset

      @primary_key {:id, TypeID, prefix: unquote(prefix), autogenerate: true}

      @foreign_key_type TypeID
      @timestamps_opts [type: :utc_datetime_usec]

      def inherit_account_id(child, %{account_id: nil}), do: child

      def inherit_account_id(child, %{account_id: account_id}), do: %{child | account_id: account_id}

      def inherit_account_id(child, _parent), do: child

      def changeset, do: changeset(struct(__MODULE__), %{})

      def changeset(entity) when is_struct(entity), do: changeset(entity, %{})

      def changeset(params) when is_map(params), do: changeset(struct(__MODULE__), params)
    end
  end
end
