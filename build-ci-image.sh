#!/bin/bash
set -euo pipefail

exec "$(dirname "$0")/scripts/build-ci-image.sh" "$@"
