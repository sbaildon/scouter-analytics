defmodule Dashboard.RemoteIPPlug do
  @moduledoc false

  def init(_opts) do
    RemoteIp.init(headers: ["x-forwarded-for"])
  end

  def call(conn, opts) do
    case conn.assigns.environment do
      :trusted ->
        opts
        |> Keyword.put(:proxies, {__MODULE__, :trusted_proxies, [conn]})
        |> then(&RemoteIp.call(conn, &1))

      :untrusted ->
        conn

      :unspecified ->
        conn
    end
  end

  def trusted_proxies(conn) do
    conn.assigns
    |> Map.get(:trusted_proxies, [])
    |> Enum.map(&to_string/1)
    |> Enum.map(&ipv4_mapped_to_ipv4/1)
  end

  defp ipv4_mapped_to_ipv4("::ffff:" <> network) do
    [address, mask] = String.split(network, "/")

    ipv4_mask = String.to_integer(mask) - mapped_ipv4_fixed_mask()

    "#{address}/#{ipv4_mask}"
  end

  defp ipv4_mapped_to_ipv4(network), do: network

  defp mapped_ipv4_fixed_mask, do: 96
end
