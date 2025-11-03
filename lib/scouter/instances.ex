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
        {Scouter.Instance, main_instance_opts()}
      ] ++ maybe_enable_dynamic_instances()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp main_instance_opts do
    case :systemd.listen_fds() do
      [] -> put_name(raw_process())
      fds -> fds |> managed_by_systemd() |> put_name()
    end
  end

  defp managed_by_systemd(fds) do
    with {:ok, socket_name} <- System.fetch_env("TELEMETRY_SOCKET"),
         {fd, _} <- List.keyfind(fds, to_charlist(socket_name), 1) do
      [fd: fd]
    else
      other ->
        raise "could not find file descriptor for socket activiation: #{inspect(other)} "
    end
  end

  defp raw_process do
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

  defp maybe_enable_dynamic_instances do
    case System.fetch_env("DYNAMIC_INSTANCE_MANAGER_SOCKET") do
      {:ok, path} ->
        [
          {DynamicSupervisor, name: Scouter.InstanceSupervisor, strategy: :one_for_one},
          {Task.Supervisor, name: Scouter.Instances.SCMReceiver},
          Supervisor.child_spec({Task, fn -> SCMEndpoint.start(path: path) end}, restart: :permanent)
        ]

      :error ->
        []
    end
  end
end
