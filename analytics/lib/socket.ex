defmodule Socket do
  def name!(env) do
    System.get_env(env) ||
      raise "socket activation enabled, requires #{env} to be set, and is usually named after your socket unit, eg: analytics-dashboard.socket"
  end

  defp fd!(fds, name) do
    List.keyfind(fds, to_charlist(name), 1) || raise "#{name} was not passed as a named socket"
  end

  def socket_activation(fds, socket_name) do
    {fd, _name} = fd!(fds, socket_name)

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
