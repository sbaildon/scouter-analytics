defmodule Dashboard.TrustedProxiesPlug do
  @moduledoc false
  import Plug.Conn

  require Logger

  def init(opts), do: Map.new(opts)

  # local unix socket are always trusted
  def call(%{remote_ip: {:local, _name}} = conn, _opts) do
    Logger.info(client: :local)
    trusted_environment(conn)
  end

  def call(conn, _opts) do
    if trusted_proxies = trusted_proxies() do
      client = conn.remote_ip

      trusted_environment? =
        Enum.any?(trusted_proxies, fn trusted_proxy -> trusted_client?(client, trusted_proxy) end)

      (trusted_environment? && trusted_environment(conn)) ||
        untrusted_environment(conn, client, trusted_proxies)
    else
      unspecified_environment(conn)
    end
  end

  defp trusted_client?(client_ip, trusted_proxy) when tuple_size(client_ip) != tuple_size(trusted_proxy.first) do
    false
  end

  defp trusted_client?(client_ip, trusted_proxy) do
    CIDR.match!(trusted_proxy, client_ip)
  end

  defp trusted_environment(conn), do: assign(conn, :environment, :trusted)

  defp untrusted_environment(conn, client, trusted_proxies) do
    Logger.warning(
      "connection received from a client other than a trusted proxy, from #{inspect(client)}, trusted #{inspect(trusted_proxies)}"
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
