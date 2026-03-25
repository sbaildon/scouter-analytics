defmodule Scouter do
  @moduledoc """
  Scouter keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  require Logger

  def name, do: "Scouter Analytics"

  def with_instance(instance_name, callback) do
    with {:ok, instance} <- Scouter.Instance.build(instance_name) do
      Logger.metadata(instance: instance_name)
      Scouter.Repo.put_dynamic_repo(instance.repo)
      Scouter.EventsRepo.put_dynamic_repo(instance.events_repo)
      callback.(instance)
    end
  end

  def start_instance(name, {:local, socket}) do
    DynamicSupervisor.start_child(
      Scouter.InstanceSupervisor,
      {Scouter.Instance, name: {:via, Registry, {Scouter.InstanceRegistry, name}}, local: socket}
    )
  end

  def start_instance(name, {:port, port}) do
    DynamicSupervisor.start_child(
      Scouter.InstanceSupervisor,
      Supervisor.child_spec(
        {Scouter.Instance, name: {:via, Registry, {Scouter.InstanceRegistry, name}}, port: port},
        restart: :temporary
      )
    )
  end

  def start_instance(name, {:fd, fd}) do
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Scouter.InstanceSupervisor,
        {Scouter.Instance, name: {:via, Registry, {Scouter.InstanceRegistry, name}}, fd: fd}
      )
  end

  def start_instance(name) do
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Scouter.InstanceSupervisor,
        {Scouter.Instance, name: {:via, Registry, {Scouter.InstanceRegistry, name}}}
      )
  end

  def stop_instance(name) do
    Logger.info("stopping instance #{name} by request")

    case Registry.lookup(Scouter.InstanceRegistry, name) do
      [{pid, _}] ->
        :ok = DynamicSupervisor.terminate_child(Scouter.InstanceSupervisor, pid)
        Logger.info("stopped instance #{name} by request")

      _ ->
        Logger.info("cannot stop #{name} because it's not running")
    end
  end

  def stop_instances do
    Logger.info("stopping all instances")

    for {_, pid, _, _} <- DynamicSupervisor.which_children(Scouter.InstanceSupervisor) do
      DynamicSupervisor.terminate_child(Scouter.InstanceSupervisor, pid)
    end
  end

  def list_instances do
    Scouter.InstanceRegistry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Keyword.keys()
  end

  def credentials_directory do
    System.get_env("CREDENTIALS_DIRECTORY", "/run/secrets")
  end
end
