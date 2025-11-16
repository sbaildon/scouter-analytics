defmodule Scouter.Instances do
  @moduledoc false
  use Supervisor

  alias Scouter.Instances.SCMEndpoint

  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, Map.new(opts), name: __MODULE__)
  end

  @impl Supervisor
  def init(_) do
    children =
      [
        {Registry, name: Scouter.InstanceRegistry, keys: :unique},
      ] ++ maybe_main_instance() ++ maybe_enable_instance_manager()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp maybe_main_instance() do
    socket = System.get_env("TELEMETRY_SOCKET")
    port = System.get_env("TELEMETRY_PORT")
    instance_manager = System.get_env("INSTANCE_MANAGER_SOCKET")

    cond do
      !socket && !port && !instance_manager ->
        raise "set TELEMETRY_PORT or TELEMETRY_SOCKET"
      !socket && !port ->
        Logger.info("main instance not configured")
        []
      true ->
        [{Scouter.Instance, main_instance_opts()}]
    end
  end

  defp main_instance_opts do
    case :systemd.listen_fds() do
      [] -> put_name(self_managed())
      fds -> fds |> systemd_managed() |> put_name()
    end
  end

  defp systemd_managed(fds) do
    with {:ok, socket_name} <- System.fetch_env("TELEMETRY_SOCKET"),
         {fd, _} <- List.keyfind(fds, to_charlist(socket_name), 1) do
      [fd: fd]
    else
      other ->
        raise "could not find file descriptor for socket activiation: #{inspect(other)} "
    end
  end

  defp self_managed do
    cond do
      socket = System.get_env("TELEMETRY_SOCKET") ->
        [local: socket]

      port = System.get_env("TELEMETRY_PORT", "4001") ->
        port
        |> String.to_integer()
        |> then(fn port -> [port: port] end)
    end
  end

  defp put_name(opts) do
    Keyword.put(opts, :name, {:via, Registry, {Scouter.InstanceRegistry, :main}})
  end

  defp maybe_enable_instance_manager do
    case :systemd.listen_fds() do
      [] -> maybe_start_self_managed_instance_manager()
      fds -> maybe_start_systemd_managed_instance_manager(fds)
    end
  end

  defp maybe_start_self_managed_instance_manager do
    case System.fetch_env("INSTANCE_MANAGER_SOCKET") do
      {:ok, path} -> instance_manager_processes(path: path)
      :error -> []
    end
  end

  def maybe_start_systemd_managed_instance_manager(fds) do
    with {:ok, socket_name} <- System.fetch_env("INSTANCE_MANAGER_SOCKET"),
         {fd, name} <- List.keyfind(fds, to_charlist(socket_name), 1) do
      Logger.info("starting instance manager with fd #{fd}, #{name}")
      instance_manager_processes(fd: fd)
    else
      _ ->
        []
    end
  end

  # manager_opts expects [fd: fd] or [path: path]
  defp instance_manager_processes(manager_opts) do
    [
      {DynamicSupervisor, name: Scouter.InstanceSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Scouter.Instances.SCMReceiver},
      Supervisor.child_spec({Task, fn -> SCMEndpoint.start(manager_opts) end}, restart: :permanent)
    ]
  end
end
