defmodule Scouter.EventsRepo do
  use Ecto.Repo,
    otp_app: :scouter,
    adapter: Ecto.Adapters.DuckDB

  def basename do
    config() |> Keyword.fetch!(:database) |> Path.basename()
  end
end
