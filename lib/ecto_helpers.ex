defmodule EctoHelpers do
  @moduledoc false

  use Gettext, backend: Dashboard.Gettext

  import Ecto.Changeset

  alias Stats.Repo

  @spec all(query :: Ecto.Query.t(), opts :: list()) :: {:ok, orders :: list(Order)}
  def all(query, opts) when is_list(opts) do
    result =
      cond do
        opts[:skip_account_id] -> Repo.all(query, skip_account_id: true)
        account_id = opts[:account_id] -> Repo.all(query, account_id: account_id)
        true -> Repo.all(query)
      end

    case result do
      nil -> nil
      entities -> {:ok, entities}
    end
  end

  @spec all(query :: Ecto.Query.t(), account_id :: Identifier.t()) :: {:ok, orders :: list(Order)}
  def all(query, account_id) do
    case_result =
      case account_id do
        :skip_account_id -> Repo.all(query, skip_account_id: true)
        account_id -> Repo.all(query, account_id: account_id)
      end

    then(case_result, fn result -> {:ok, result} end)
  end

  @spec one(query :: Ecto.Query.t()) ::
          {:ok, Ecto.Schema.t()} | nil
  def one(query), do: one(query, [])

  @spec one(query :: Ecto.Query.t(), opts :: list()) ::
          {:ok, Ecto.Schema.t()} | nil
  def one(query, opts) when is_list(opts) do
    result =
      cond do
        opts[:skip_account_id] -> Repo.one(query, skip_account_id: true)
        account_id = opts[:account_id] -> Repo.one(query, account_id: account_id)
        true -> Repo.one(query)
      end

    case result do
      nil -> nil
      entity -> {:ok, entity}
    end
  end

  @spec one(query :: Ecto.Query.t(), account_id :: Identifier.t()) ::
          {:ok, Ecto.Schema.t()} | nil
  def one(query, account_id) do
    case_result =
      case account_id do
        :skip_account_id -> Repo.one(query, skip_account_id: true)
        account_id -> Repo.one(query, account_id: account_id)
      end

    case case_result do
      nil -> nil
      entity -> {:ok, entity}
    end
  end

  def take_from_multi({:error, op, val, _}, key) when key == op do
    {:error, val}
  end

  def take_from_multi({:error, _, _, _} = multi, _key), do: multi

  def take_from_multi({:ok, updates}, key) do
    {:ok, Map.fetch!(updates, key)}
  end

  def preload(query) do
    assocs = build_preload_from_joins(query)

    %{query | assocs: assocs}
  end

  defp build_preload_from_joins(%{joins: []}), do: []

  defp build_preload_from_joins(%{joins: joins}) do
    total_joins = Enum.count(joins)

    {0, preloads} =
      joins
      |> Enum.reverse()
      |> Enum.reduce({total_joins, %{}}, fn
        # this case is written to prevent preloading in simple
        # subqueries. likely # breaks in more complex situations. wrriten
        # for the simplest # usecase. don't assume this is 'correct' code.
        %{assoc: nil}, {index, map} ->
          {index - 1, map}

        %{assoc: {pos, assoc}}, {index, map}
        when is_map_key(map, pos) and is_map_key(map, index) ->
          {put_popped_index_in_here, updated_map} = Map.pop(map, pos)
          {popped_index, updated_map} = Map.pop(updated_map, index)

          popped_index = %{popped_index | value: assoc}

          put_popped_index_in_here =
            Map.update!(put_popped_index_in_here, :children, fn children ->
              Map.put(children, index, popped_index)
            end)

          {index - 1, Map.put(updated_map, pos, put_popped_index_in_here)}

        %{assoc: {pos, assoc}}, {index, map} when is_map_key(map, pos) ->
          {value, updated_map} = Map.pop(map, pos)

          assoc_node = %{
            children: %{},
            value: assoc
          }

          value =
            Map.update!(value, :children, fn children ->
              Map.put(children, index, assoc_node)
            end)

          {index - 1, Map.put(updated_map, pos, value)}

        %{assoc: {pos, assoc}}, {index, map} when is_map_key(map, index) ->
          {child_node, updated_map} = Map.pop(map, index)

          child_node = %{child_node | value: assoc}

          node = %{
            children: %{index => child_node},
            value: nil
          }

          {index - 1, Map.put(updated_map, pos, node)}

        %{assoc: {pos, assoc}}, {index, map} ->
          assoc_node = %{
            children: %{},
            value: assoc
          }

          node = %{
            children: %{index => assoc_node},
            value: nil
          }

          {index - 1, Map.put(map, pos, node)}
      end)

    {nil, {0, rest}} =
      preloads
      |> convert_to_assocs()
      |> List.first()

    rest
  end

  defp convert_to_assocs(map) do
    Enum.map(map, fn
      {k, %{children: children, value: assoc}} when map_size(children) == 0 ->
        {assoc, {k, []}}

      {k, %{children: children, value: assoc}} ->
        {assoc, {k, convert_to_assocs(children)}}
    end)
  end

  def validate_slug(changeset) do
    validate_slug(changeset, :slug)
  end

  def validate_slug(changeset, field) do
    validate_format(changeset, field, ~r/^[a-z0-9]+(?:[_-][a-z0-9]+)*$/,
      message: "Lower cased letters, numbers, dashes, and underscores. Must start with a letter."
    )
  end

  def if_changed(changeset, field, fun) when is_function(fun, 1) do
    if changed?(changeset, field) do
      fun.(changeset)
    else
      changeset
    end
  end

  def validate_email(changeset, field \\ :email) do
    changeset
    |> validate_required([field], message: gettext("An email is required"))
    |> validate_format(field, ~r/^[^\s]+@[^\s]+$/, message: "An email must contain @, with no spaces")
  end

  @type predicate :: atom

  def validate_if(changeset, predicate, func) when is_function(func, 1) and is_atom(predicate) do
    if get_field(changeset, predicate) do
      func.(changeset)
    else
      changeset
    end
  end

  def validate_mutually_exclusive(changeset, keys) do
    included_values =
      keys |> Enum.map(fn key -> {key, get_field(changeset, key)} end) |> Enum.count(fn {_, value} -> value != nil end)

    if included_values > 1 do
      Enum.reduce(keys, changeset, fn key, acc ->
        exclusive_list =
          keys
          |> List.delete(key)
          |> Enum.map(&Atom.to_string/1)

        add_error(acc, key, "is mutually exclsuive with #{exclusive_list}")
      end)
    else
      changeset
    end
  end

  def validate_uri(changeset, field) do
    validate_change(changeset, field, fn
      key, %{scheme: nil} -> [{key, "needs a scheme"}]
      key, %{host: host} when host in [nil, ""] -> [{key, "needs a host"}]
      _, _ -> []
    end)
  end

  def validate_unix_time(changeset, key) do
    validate_number(changeset, key, greater_than_or_equal_to: 1_105_829_760, less_than_or_equal_to: 253_402_300_799)
  end
end
