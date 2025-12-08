#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "entering repo.."
cd "$SCRIPT_DIR/gr-tetra"

echo "building cross-compile image..."
docker compose build

echo "exporting cross-compile image to file..."
# TODO add docker export code
fi
