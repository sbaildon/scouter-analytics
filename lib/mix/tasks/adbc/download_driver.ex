defmodule Mix.Tasks.Adbc.DownloadDriver do
  @shortdoc "Downloads an ADBC driver"

  @moduledoc false
  use Mix.Task

  def run([driver]) do
    Mix.shell().info("Downloading #{driver} driver...")
    Adbc.download_driver(String.to_atom(driver))
  end

  def run(_) do
    Mix.shell().error("Usage: mix adbc.download_driver <driver_name>")
  end
end
