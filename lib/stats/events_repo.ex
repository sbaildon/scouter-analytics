defmodule Stats.EventsRepo do
  use Ecto.Repo,
    otp_app: :stats,
    adapter: Ecto.Adapters.DuckDB
end
