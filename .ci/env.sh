PROJECT_REVISION=$(git rev-parse --short HEAD)
export PROJECT_REVISION

BRANCH=$(git name-rev --name-only HEAD)
export BRANCH

BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export BUILD_TIME
