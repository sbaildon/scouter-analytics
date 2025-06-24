set dotenv-load := true

default_repo := "Scouter.Repo"
otp_app := "scouter"

serve:
    iex --name analytics@127.0.0.1 --cookie $RELEASE_COOKIE -S mix phx.server

proxy config="Caddyfile":
    nix run .#caddy -- run --config={{ config }} --watch

olap:
    nix shell nixpkgs#postgresql --command postgres -k $XDG_RUNTIME_DIR/scouter -D $XDG_STATE_HOME/scouter/event_db

storage:
    nix run .#minio -- server --address 127.0.0.1:${MINIO_API_PORT} --console-address 127.0.0.1:${MINIO_CONSOLE_PORT} ${XDG_DATA_HOME}/{{ otp_app }}

vm name='elixir' filename='elixir':
    #!/usr/bin/env fish
    cat dev/virtual_machines/{{ filename }}.yaml \
        | yq '.mounts += {"location": "'$(pwd)'", "writeable": true}' \
        | limactl start --name={{ name }} -

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

contain vm_name="builder":
    #!/usr/bin/env bash
    set -euxo pipefail
    limactl rm --force {{ vm_name }}
    export BUILD_DIR=$(mktemp -d)
    git clone .. ${BUILD_DIR}
    cat .ci/image.yaml \
        | yq '.mounts = []' \
        | yq '.mounts[0] = {"location": env(BUILD_DIR)}' \
        | yq '.mounts[1] = {"location": env(XDG_CONFIG_HOME) + "/containers/", "mountPoint": "/run/containers/0/"}' \
        | limactl create --name={{ vm_name }} -
    limactl start {{ vm_name }}
    limactl rm --force {{ vm_name }}
    limactl shell --workdir="${BUILD_DIR}/analytics" {{ vm_name }} .ci/build.sh
