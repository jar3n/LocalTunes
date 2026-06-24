#!/usr/bin/env bash
set -euo pipefail

IMAGE="localtunes-builder"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Prefer docker over podman (GitHub CI has docker, local dev may use podman)
if command -v docker &>/dev/null; then
    RUNTIME="docker"
elif command -v podman &>/dev/null; then
    RUNTIME="podman"
else
    echo "Error: neither docker nor podman found" >&2
    exit 1
fi

# Check if the container image already exists
image_exists() {
    if [ "$RUNTIME" = "podman" ]; then
        "$RUNTIME" image exists "$IMAGE" 2>/dev/null
    else
        "$RUNTIME" images -q "$IMAGE" 2>/dev/null | grep -q .
    fi
}

if ! image_exists; then
    echo "==> Building container image (first time only, this takes a few minutes)..."
    "$RUNTIME" build -t "$IMAGE" "$PROJECT_DIR"
fi

echo "==> Building LocalTunes..."
mkdir -p "$PROJECT_DIR/packages"
"$RUNTIME" run --rm \
    -v "$PROJECT_DIR:/project" \
    "$IMAGE" \
    make package FINALPACKAGE=1

echo ""
echo "==> Done! .deb is in: $PROJECT_DIR/packages/"
ls -lh "$PROJECT_DIR"/packages/*.deb 2>/dev/null || echo "(no .deb found)"
