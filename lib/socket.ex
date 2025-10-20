defmodule Socket do
  def name!(env) do
    System.get_env(env) ||
      raise "socket activation enabled, requires #{env} to be set, and is usually named after your socket unit, eg: analytics-dashboard.socket"
  end

  def systemd(fds, socket_name) do
    socket_activation(fds, socket_name)
  end

  def fd(fds, socket_name) do
    {fd, _} =
      List.keyfind(fds, to_charlist(socket_name), 1) ||
        raise "#{socket_name} was not passed as a named socket, received #{inspect(fds)}"

    fd
  end

  def socket_activation(fds, socket_name) do
    {fd, _} =
      List.keyfind(fds, to_charlist(socket_name), 1) ||
        raise "#{socket_name} was not passed as a named socket, received #{inspect(fds)}"

    [
      thousand_island_options: [
        port: 0,
        transport_options: [
          {:fd, fd},
          :local
        ]
      ]
    ]
  end

  def af_inet6(name, default) do
    [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port(name, default)
    ]
  end

  def port(name, default) do
    name |> System.get_env(default) |> String.to_integer()
  end
end
