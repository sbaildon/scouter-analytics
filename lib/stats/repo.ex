defmodule Stats.Repo do
  use Ecto.Repo,
    otp_app: :stats,
    adapter: Ecto.Adapters.SQLite3
end
