#!/usr/bin/env bash
# shellcheck disable=2086
set -euxo pipefail

source .ci/env.sh

sudo buildah build-using-dockerfile \
	--annotation org.opencontainers.image.revision=${PROJECT_REVISION} \
	--annotation org.opencontainers.image.created=${BUILD_TIME} \
	--annotation org.opencontainers.image.source="https://git.sr.ht/~sbaildon/analytics" \
	--annotation org.opencontainers.image.url="https://git.sr.ht/~sbaildon/analytics" \
	--no-cache \
	--jobs=1 \
	--manifest registry.b5n.dev/analytics:${PROJECT_REVISION} \
	--platform=linux/arm64 .
