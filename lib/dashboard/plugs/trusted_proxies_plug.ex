defmodule Dashboard.TrustedProxiesPlug do
  @moduledoc false
  import Bitwise
  import Plug.Conn

  require Logger

  defmacro is_ipv4_mapped_ipv6("::ffff:" <> _), do: true
  defmacro is_ipv4_mapped_ipv6(_any), do: false

  def init(opts), do: Map.new(opts)

  def call(conn, _opts) do
    {:ok, remote_ip} = remote_ip(conn)

    trusted_environment? =
      Enum.any?(trusted_proxies(), fn trusted ->
        remote_ip <= trusted.last && remote_ip >= trusted.first
      end)

    (trusted_environment? && trusted_environment(conn)) || untrusted_environment(conn)
  end

  defp trusted_environment(conn), do: assign(conn, :trusted_environment?, true)
  defp untrusted_environment(conn), do: assign(conn, :trusted_environment?, false)

  defp remote_ip(conn) do
    {:ok,
     conn
     |> Map.fetch!(:remote_ip)
     |> to_ipv6()}
  end

  defp to_ipv6({_, _, _, _} = ipv4), do: map_v4_to_v6(ipv4)
  defp to_ipv6({_, _, _, _, _, _, _, _} = ipv6), do: ipv6

  defp map_v4_to_v6({a, b, c, d}), do: {0, 0, 0, 0, 0, 65_535, (a <<< 8) + b, (c <<< 8) + d}

  defp ipv4_mapped_prefix, do: "::ffff:"

  defp trusted_proxies do
    trusted_proxies =
      case Dashboard.Endpoint.config(:trusted_proxies) do
        nil -> []
        config when is_binary(config) -> String.split(config, ";")
      end

    Enum.map(trusted_proxies, &parse_cidr/1)
  end

  def parse_cidr(network) when is_ipv4_mapped_ipv6(network), do: CIDR.parse(network)
  def parse_cidr(network), do: network |> ipv4_network_to_ipv6() |> CIDR.parse()

  defp ipv4_network_to_ipv6(ipv4_network) do
    [ip, mask] = String.split(ipv4_network, "/")

    ipv6_mask = String.to_integer(mask) + 96

    "#{ipv4_mapped_prefix()}#{ip}/#{ipv6_mask}"
  end
end
