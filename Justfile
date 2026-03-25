set dotenv-load := true

default_repo := "Scouter.Repo"
otp_app := "scouter"

serve:
    iex --name analytics@127.0.0.1 --cookie $RELEASE_COOKIE -S mix phx.server

proxy config="Caddyfile":
    nix run .#caddy -- run --config={{ config }} --watch

infra:
    nix run .#hivemind -- --processes=proxy,storage

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

download-libduckdb version dir=".local/lib":
    #!/usr/bin/env bash
    set -euo pipefail
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "$os" in
        darwin) platform="osx"; arch="universal" ;;
        linux)  platform="linux" ;;
        *)      echo "Unsupported OS: $os"; exit 1 ;;
    esac
    url="https://github.com/duckdb/duckdb/releases/download/v{{ version }}/libduckdb-${platform}-${arch}.zip"
    mkdir -p {{ dir }}
    tmp=$(mktemp)
    curl -fSL "$url" -o "$tmp"
    unzip -o "$tmp" -d {{ dir }}
    rm "$tmp"

download-duckdb-extension name version dir=".local/lib/duckdb/extensions":
    #!/usr/bin/env bash
    set -euo pipefail
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "$os" in
        darwin) platform="osx"; arch="arm64" ;;
        linux)  platform="linux"; arch="${arch/x86_64/amd64}" ;;
        *)      echo "Unsupported OS: $os"; exit 1 ;;
    esac
    url="https://extensions.duckdb.org/v{{ version }}/${platform}_${arch}/{{ name }}.duckdb_extension.gz"
    outdir="{{ dir }}/v{{ version }}/${platform}_${arch}"
    mkdir -p "$outdir"
    curl -fSL "$url" | gunzip > "$outdir/{{ name }}.duckdb_extension"
