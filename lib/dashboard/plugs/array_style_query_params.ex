defmodule Dashboard.ArrayStyleQueryParamsPlug do
  @moduledoc """
  a copy and paste of https://github.com/elixir-plug/plug/blob/065976d85f3d079d4f22dde7897c2e7f67c596e0/lib/plug/conn.ex#L1106
  fetch_query_params/2 except using URI.query_decoder/2 and parsing all query params into arrays
  """
  alias Plug.Conn.Unfetched

  def init(opts), do: Keyword.new(opts)

  def call(%Plug.Conn{query_params: %Unfetched{}} = conn, opts) do
    %{params: params, query_string: query_string} = conn
    length = Keyword.get(opts, :length, 1_000_000)

    if byte_size(query_string) > length do
      raise Plug.Conn.InvalidQueryError,
        message: "maximum query string length is #{length}, got a query with #{byte_size(query_string)} bytes",
        plug_status: 414
    end

    query_params =
      query_string
      |> URI.query_decoder(:rfc3986)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    case params do
      %Unfetched{} -> %{conn | query_params: query_params, params: query_params}
      %{} -> %{conn | query_params: query_params, params: Map.merge(query_params, params)}
    end
  end

  def call(%Plug.Conn{} = conn, _opts) do
    conn
  end
end
