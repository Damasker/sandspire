#!/usr/bin/env bash
# Publish playable Sandspire builds to the LAN Samba share (server 110).
# Share path: /srv/media/sandspire  →  \\192.168.168.110\media\sandspire
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARE="${SANDSPIRE_SHARE:-/srv/media/sandspire}"
VERSION_FILE="$ROOT/scripts/version.gd"

if [[ ! -d /srv/media ]]; then
  echo "error: /srv/media missing — expected Samba [media] share root" >&2
  exit 1
fi

mkdir -p "$SHARE/windows" "$SHARE/linux"

VERSION="0.0.0"
if [[ -f "$VERSION_FILE" ]]; then
  VERSION="$(grep -E 'const VERSION' "$VERSION_FILE" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
fi
STAMP="$(date -u +%Y-%m-%dT%H:%MZ)"
GIT_SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# Prefer Windows build for Windows clients; Linux always useful on the box itself.
copied=0
if [[ -f "$ROOT/build/windows/Sandspire.exe" ]]; then
  rm -rf "$SHARE/windows"
  mkdir -p "$SHARE/windows"
  cp -a "$ROOT/build/windows/." "$SHARE/windows/"
  copied=1
  echo "published windows → $SHARE/windows/"
else
  echo "warn: no Windows build at build/windows/Sandspire.exe" >&2
fi

if [[ -f "$ROOT/build/linux/Sandspire.x86_64" ]]; then
  rm -rf "$SHARE/linux"
  mkdir -p "$SHARE/linux"
  cp -a "$ROOT/build/linux/." "$SHARE/linux/"
  chmod +x "$SHARE/linux/Sandspire.x86_64" 2>/dev/null || true
  # Godot may also emit a console wrapper next to the main binary
  if [[ -f "$SHARE/linux/Sandspire.x86_64.console" ]]; then
    chmod +x "$SHARE/linux/Sandspire.x86_64.console" 2>/dev/null || true
  fi
  copied=1
  echo "published linux → $SHARE/linux/"
else
  echo "warn: no Linux build at build/linux/Sandspire.x86_64" >&2
fi

if [[ "$copied" -eq 0 ]]; then
  echo "error: nothing to publish — run make export-windows and/or export-linux first" >&2
  exit 1
fi

cat > "$SHARE/README_TEST.txt" <<EOF
Sandspire — LAN test build
==========================

Version:  ${VERSION}
Git:      ${GIT_SHA}
Built:    ${STAMP} (UTC)
Share:    \\\\192.168.168.110\\media\\sandspire
          (also \\\\home-mike\\media\\sandspire if DNS resolves)

How to run (Windows client)
---------------------------
1. Open File Explorer → \\\\192.168.168.110\\media\\sandspire
2. Go into the windows\\ folder
3. Double-click Sandspire.exe

If Windows asks for credentials: try guest / blank password, or user mike
(Samba [media] allows guest; map-to-guest = Bad User).

Linux binary (on the server or Linux clients)
--------------------------------------------
  linux/Sandspire.x86_64

Refresh the build (on home-mike)
--------------------------------
  cd /home/mike/projects/sandspire
  make publish-share
  # or rebuild then publish:
  make export-windows export-linux publish-share

Controls (summary)
------------------
  WASD / arrows     Pan camera
  Wheel            Zoom
  LMB / Shift+LMB  Select
  RMB              Move / attack
  A / S / H        Attack-move / Stop / Hold
  1–6              Place buildings
  Q–Y              Produce (selected factory)
  B                Advisor
  O                Options
  ? / F1           Hotkeys
  F5 / F9          Quicksave / Quickload

Repo: https://github.com/Damasker/sandspire
EOF

# Keep a tiny stamp file for scripts / sanity checks
cat > "$SHARE/BUILD_INFO.txt" <<EOF
version=${VERSION}
git=${GIT_SHA}
built_utc=${STAMP}
unc=\\\\192.168.168.110\\media\\sandspire
EOF

# Ensure share group perms stay friendly for media share
chgrp -R media "$SHARE" 2>/dev/null || true
chmod -R g+rwX,o+rX "$SHARE" 2>/dev/null || true

echo ""
echo "OK — test build ready:"
echo "  UNC:  \\\\192.168.168.110\\media\\sandspire"
echo "  Run:  \\\\192.168.168.110\\media\\sandspire\\windows\\Sandspire.exe"
ls -la "$SHARE" "$SHARE/windows" "$SHARE/linux" 2>/dev/null || true
