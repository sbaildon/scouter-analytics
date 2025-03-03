defmodule Ecto.Adapters.DuckDB.Query do
  @moduledoc false

  defstruct [:statement, :name, :ref]

  defimpl DBConnection.Query do
    require Logger

    def parse(query, _opts) do
      query
    end

    def describe(query, _opts) do
      query
    end

    def encode(_query, params, _opts) do
      Enum.map(params, &encode_param/1)
    end

    defp encode_param(%NaiveDateTime{} = param), do: NaiveDateTime.to_iso8601(param)
    defp encode_param(%DateTime{} = param), do: DateTime.to_iso8601(param)
    defp encode_param(%Decimal{} = param), do: Decimal.to_string(param)
    defp encode_param(param), do: param

    def decode(_query, %Adbc.Result{} = result, _opts) do
      {num_rows, materialized_rows} =
        result
        |> Adbc.Result.materialize()
        |> columns_to_rows()

      %{num_rows: num_rows, rows: materialized_rows}
    end

    def decode(_query, result, _opts) do
      result
    end

    defp columns_to_rows(adbc_result) do
      adbc_result.data
      |> Enum.map(&Map.fetch!(&1, :data))
      |> Enum.zip_reduce({0, []}, fn row, {count, rows} ->
        {count + 1, [row | rows]}
      end)
    end
  end

  defimpl String.Chars do
    def to_string(%{statement: statement}) do
      IO.iodata_to_binary(statement)
    end
  end
end
