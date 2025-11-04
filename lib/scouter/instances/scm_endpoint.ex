defmodule Scouter.Instances.SCMEndpoint do
  @moduledoc false
  require Logger

  def start(opts) do
    case socket(opts) do
      {:ok, socket} ->
        Logger.info("listening for instance requests")
        accept_connection(socket)

      other ->
        Logger.warning("failed to start #{inspect(other)}")
    end
  end

  defp socket(opts) do
    cond do
      path = Keyword.get(opts, :path) -> self_managed_socket(path)
      fd = Keyword.get(opts, :fd) -> systemd_managed_socket(fd)
      true -> raise "scm socket neeeds :path or :fd"
    end
  end

  defp self_managed_socket(path) do
    with {:ok, _path} <- clean_socket(path),
         {:ok, socket} <- :socket.open(:local, :stream, :default),
         :ok <- :socket.bind(socket, %{family: :local, path: path}),
         :ok <- :socket.listen(socket) do
        Logger.info("listening for instances from #{path}")
      {:ok, socket}
    end
  end

  defp systemd_managed_socket(fd) do
    with {:ok, socket} <- :socket.open(fd),
         :ok <- :socket.listen(socket) do
      {:ok, socket}
    end
  end

  defp accept_connection(socket) do
    {:ok, client} = :socket.accept(socket, :infinity)
    {:ok, _pid} = Task.Supervisor.start_child(Scouter.Instances.SCMReceiver, fn -> serve(client) end)
    accept_connection(socket)
  end

  def serve(socket) do
    case :socket.recvmsg(socket) do
      {:ok, %{iov: [message], ctrl: [%{type: :rights, data: <<fd::native-integer-size(32)>>}]}} ->
        Logger.info("starting instance #{message} via fd #{inspect(fd)}")
        Scouter.start_instance(message, {:fd, fd})

      {:error, reason} ->
        Logger.info("error receiving message #{inspect(reason)}")
        {:error, reason}

      other ->
        Logger.info("received unexpected message #{inspect(other)}")
        {:error, nil}
    end
  end

  defp clean_socket(<<0, _rest::binary>> = abstract_namespace_socket), do: {:ok, abstract_namespace_socket}

  defp clean_socket(path) do
    case File.rm(path) do
      :ok -> {:ok, path}
      {:error, :enoent} -> {:ok, path}
      other -> {:error, other}
    end
  end
end
