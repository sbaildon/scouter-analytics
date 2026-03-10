defmodule Mix.Tasks.DownloadAdbcDriver do
  use Mix.Task

  @shortdoc "Downloads an ADBC driver"

  def run([driver]) do
    Mix.shell().info("Downloading #{driver} driver...")
    Adbc.download_driver(String.to_atom(driver))
  end

  def run(_) do
    Mix.shell().error("Usage: mix download_driver <driver_name>")
  end
end
