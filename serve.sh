#!/usr/bin/env bash
# Serves the packages/ folder over HTTP so you can download the .deb
# from your iPod's Safari browser via your hotspot.
set -euo pipefail

cd "$(dirname "$0")/packages"
echo "==> Available .deb files:"
ls -lh *.deb 2>/dev/null || echo "(no .deb found — run build-in-container.sh first)"

echo ""
echo "==> Serving on http://0.0.0.0:8080/"
echo "    On your iPod, open Safari and go to:"
echo "    http://$(hostname -I | awk '{print $1}'):8080/"
echo "    (use the IP of this machine from 'ip addr' if the above doesn't work)"
echo "    Press Ctrl+C to stop."
echo ""

exec python3 -m http.server 8080
