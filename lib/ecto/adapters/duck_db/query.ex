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
    defp encode_param(param) when is_map(param), do: JSON.encode_to_iodata!(param)
    defp encode_param(param), do: param

    def decode(_query, %Adbc.Result{} = result, _opts) do
      {num_rows, rows} =
        result
        |> Adbc.Result.to_map()
        |> Map.values()
        |> Enum.zip_reduce({0, []}, fn row, {count, acc} ->
          {count + 1, [row | acc]}
        end)

      %{num_rows: num_rows, rows: rows}
    end

    def decode(_query, result, _opts) do
      result
    end
  end

  defimpl String.Chars do
    def to_string(%{statement: statement}) do
      IO.iodata_to_binary(statement)
    end
  end
end
