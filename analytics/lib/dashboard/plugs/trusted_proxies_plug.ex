defmodule Dashboard.TrustedProxiesPlug do
  @moduledoc false
  import Plug.Conn

  require Logger

  def init(opts), do: Map.new(opts)

  def call(conn, _opts) do
    if trusted_proxies = trusted_proxies() do
      forwarded_for =
        conn
        |> get_req_header("x-forwarded-for")
        |> Enum.flat_map(&parse_header/1)

      client_and_proxy_pairs =
        for client <- forwarded_for, trusted_proxy <- trusted_proxies do
          {client, trusted_proxy}
        end

      trusted_environment? =
        Enum.any?(client_and_proxy_pairs, fn {client, proxy} ->
          Logger.debug(proxy: proxy, forwarded: client)
          trusted_client?(client, proxy)
        end)

      (trusted_environment? && trusted_environment(conn)) || untrusted_environment(conn, forwarded_for, trusted_proxies)
    else
      unspecified_environment(conn)
    end
  end

  defp parse_header("for=" <> _ = header), do: RemoteIp.Parsers.Forwarded.parse(header)
  defp parse_header(header), do: RemoteIp.Parsers.Generic.parse(header)

  defp trusted_client?(client_ip, trusted_proxy) do
    client_ip <= trusted_proxy.last && client_ip >= trusted_proxy.first
  end

  defp trusted_environment(conn), do: conn |> assign(:environment, :trusted) |> put_session(:environment, :trusted)

  defp untrusted_environment(conn, forwarded_for, trusted_proxies) do
    Logger.warning(
      "connection received from a client other than a trusted proxy, from #{inspect(forwarded_for)}, trusted #{inspect(trusted_proxies)}"
    )

    conn
    |> assign(:environment, :untrusted)
    |> send_resp(:internal_server_error, "internal server error")
    |> halt()
  end

  defp unspecified_environment(conn),
    do: conn |> assign(:environment, :unspecified) |> put_session(:environment, :unspecified)

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

  def trusted_proxies_remote_ip do
    Enum.map(trusted_proxies() || [], &to_string/1)
  end

  defp parse_cidr!(network) do
    case CIDR.parse(network) do
      {:error, reason} -> raise "#{inspect(reason)}"
      cidr -> cidr
    end
  end
end
