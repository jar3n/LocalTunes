#!/usr/bin/env bash
set -euo pipefail

IMAGE="localtunes-builder"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Prefer podman (rootless) over docker to avoid root-owned file issues.
# GitHub Actions CI may use docker, but that's fine there.
if command -v podman &>/dev/null; then
    RUNTIME="podman"
elif command -v docker &>/dev/null; then
    RUNTIME="docker"
else
    echo "Error: neither podman nor docker found" >&2
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

# Clean up stale .theos directory if needed (no sudo required).
# With podman (rootless), files are user-owned and rm works directly.
# With docker, files are root-owned — use podman unshare or warn.
clean_theos() {
    if [ ! -d "$PROJECT_DIR/.theos" ]; then
        return 0  # nothing to clean
    fi
    # Fast path: try normal removal (works for user-owned files)
    rm -rf "$PROJECT_DIR/.theos" 2>/dev/null && return 0
    # Fallback: root-owned via podman user namespace
    if command -v podman &>/dev/null; then
        podman unshare rm -rf "$PROJECT_DIR/.theos" 2>/dev/null && return 0
    fi
    # Last resort: truly root-owned (from docker)
    echo "Warning: .theos is root-owned. Run this once to fix:" >&2
    echo "  sudo rm -rf $PROJECT_DIR/.theos" >&2
    return 1
}
clean_theos || true

echo "==> Building LocalTunes..."
mkdir -p "$PROJECT_DIR/packages"
"$RUNTIME" run --rm \
    -v "$PROJECT_DIR:/project" \
    "$IMAGE" \
    sh -c '
set -e

# Patch liblaunch out of ALL SDK .tbd stubs
sed -i '/liblaunch/d' /opt/theos/sdks/iPhoneOS9.3.sdk/usr/lib/*.tbd 2>/dev/null || true

	# Add missing libc symbols (memcpy etc.) to libsystem_c.tbd
	# The SDK stubs are incomplete and lack these basic C library symbols.
	for sym in _memcpy _memmove _memset _memcmp _memchr _memset_pattern16 _strdup _strndup _strtok_r _strcasestr _strncasecmp _strcasecmp; do
	    # Match exact symbol, not substring (e.g. _memcpy in ___memcpy_chk)
	    if ! grep -E "\\b${sym}\\b" /opt/theos/sdks/iPhoneOS9.3.sdk/usr/lib/system/libsystem_c.tbd 2>/dev/null; then
	        sed -i "s/_wcscasecmp_l/&, $sym/" /opt/theos/sdks/iPhoneOS9.3.sdk/usr/lib/system/libsystem_c.tbd
	        echo "Added $sym"
	    fi
	done

# Symlink OGG/Vorbis headers into Theos include path (avoids -fmodules interaction with -I)
ln -sf /opt/local/include/ogg /opt/theos/include/ogg
ln -sf /opt/local/include/vorbis /opt/theos/include/vorbis

# Rebuild static libs with toolchain libtool (Apple-style archive with TOC)
# The Dockerfile builds them with GNU ar which produces archives without TOC.
LIBTOOL=/opt/theos/toolchain/linux/iphone/bin/libtool
for lib in libogg libvorbis libvorbisfile; do
    rm -rf /tmp/rb_$lib && mkdir -p /tmp/rb_$lib
    (cd /tmp/rb_$lib && /usr/bin/ar x "/opt/local/lib/$lib.a")
    # Ignore "has no symbols" warnings (lookup.o is an optimization table)
    $LIBTOOL -static -o "/opt/local/lib/$lib.a" /tmp/rb_$lib/*.o 2>&1 || true
done

cd /project
exec make package FINALPACKAGE=1
'

echo ""
echo "==> Done! .deb is in: $PROJECT_DIR/packages/"
ls -lh "$PROJECT_DIR"/packages/*.deb 2>/dev/null || echo "(no .deb found)"
