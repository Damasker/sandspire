#!/usr/bin/env bash
# Install Godot 4.7.1 Linux x86_64 into ~/.local/bin/godot
set -euo pipefail
VERSION="${GODOT_VERSION:-4.7.1}"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
TMP="$(mktemp -d)"
BIN_DIR="${HOME}/.local/bin"
mkdir -p "${BIN_DIR}"
echo "Downloading ${URL}"
curl -fsSL "${URL}" -o "${TMP}/godot.zip"
unzip -o "${TMP}/godot.zip" -d "${TMP}"
SRC="$(find "${TMP}" -type f -name 'Godot_v*_linux.x86_64' | head -n1)"
install -m 755 "${SRC}" "${BIN_DIR}/godot"
rm -rf "${TMP}"
echo "Installed: ${BIN_DIR}/godot"
"${BIN_DIR}/godot" --version
