#!/usr/bin/env bash
set -euo pipefail

IMAGE="localtunes-builder"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build the container image if it doesn't exist
if ! podman image exists "$IMAGE" 2>/dev/null; then
    echo "==> Building container image (first time only, this takes a few minutes)..."
    podman build -t "$IMAGE" "$PROJECT_DIR"
fi

echo "==> Building LocalTunes..."
mkdir -p "$PROJECT_DIR/packages"
podman run --rm \
    -v "$PROJECT_DIR:/project:z" \
    "$IMAGE" \
    make package FINALPACKAGE=1

echo ""
echo "==> Done! .deb is in: $PROJECT_DIR/packages/"
ls -lh "$PROJECT_DIR"/packages/*.deb 2>/dev/null || echo "(no .deb found)"
