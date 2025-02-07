set dotenv-load := true

default_repo := "Stats.Repo"
otp_app := "stats"

serve:
    iex -S mix phx.server

proxy:
    nix run .#caddy -- run --watch

storage:
    nix run .#minio -- server --address 127.0.0.1:${MINIO_API_PORT} --console-address 127.0.0.1:${MINIO_CONSOLE_PORT} ${XDG_DATA_HOME}/{{ otp_app }}

reset-db repo=default_repo:
    mix ecto.drop -r {{ repo }}
    just setup-db {{ repo }}

setup-db repo=default_repo:
    mix ecto.create -r {{ repo }}
    mix ecto.migrate -r {{ repo }}
    mix run priv/repo/seeds.exs

migrate repo=default_repo:
    mix ecto.migrate --no-compile -r {{ repo }}

rollback to repo=default_repo:
    mix ecto.rollback --no-compile -r {{ repo }} --to={{ to }}
