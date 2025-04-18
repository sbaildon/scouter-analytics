#!/usr/bin/env bash
# shellcheck disable=2086
set -euxo pipefail

source .ci/env.sh

sudo buildah manifest \
	push \
	--all \
	registry.b5n.dev/analytics:${PROJECT_REVISION} \
	docker://registry.b5n.dev/analytics:${PROJECT_REVISION}
