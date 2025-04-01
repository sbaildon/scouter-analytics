defmodule Dashboard.TrustedProxiesPlug do
  @moduledoc false
  import Bitwise
  import Plug.Conn

  require Logger

  def init(opts), do: Map.new(opts)

  def call(conn, _opts) do
    if trusted_proxies = trusted_proxies() do
      {:ok, remote_ip} = remote_ip(conn)

      trusted_environment? =
        Enum.any?(trusted_proxies, fn trusted ->
          remote_ip <= trusted.last && remote_ip >= trusted.first
        end)

      (trusted_environment? && trusted_environment(conn)) || untrusted_environment(conn)
    else
      unspecified_environment(conn)
    end
  end

  defp trusted_environment(conn), do: assign(conn, :environment, :trusted)
  defp untrusted_environment(conn), do: assign(conn, :environment, :untrusted)
  defp unspecified_environment(conn), do: assign(conn, :environment, :unspecified)

  defp client_ip(conn) do
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
    case Dashboard.Endpoint.config(:trusted_proxies) do
      nil ->
        nil

      networks when is_binary(networks) ->
        networks
        |> String.split(";")
        |> Enum.map(&parse_cidr!/1)
    end
  end

  def parse_cidr!("::ffff:" <> _ = network) do
    case CIDR.parse(network) do
      {:error, reason} -> raise "#{inspect(reason)}"
      cidr -> cidr
    end
  end

  def parse_cidr!(network), do: network |> ipv4_network_to_ipv6() |> parse_cidr!()

  defp ipv4_network_to_ipv6(network)  do
    [ip, mask] = String.split(network, "/")

    ipv6_mask = String.to_integer(mask) + 96

     "#{ipv4_mapped_prefix()}#{ip}/#{ipv6_mask}"
  end
end
