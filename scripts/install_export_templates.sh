#!/usr/bin/env bash
# Install Godot 4.7.1 export templates for Sandspire (server 110).
set -euo pipefail
VER="4.7.1.stable"
TPZ_NAME="Godot_v4.7.1-stable_export_templates.tpz"
DEST="${HOME}/.local/share/godot/export_templates/${VER}"
URLS=(
  "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/${TPZ_NAME}"
  "https://github.com/godotengine/godot/releases/download/4.7.1-stable/${TPZ_NAME}"
)

if [[ -f "${DEST}/linux_release.x86_64" || -f "${DEST}/linux_x86_64" ]]; then
  echo "Templates already installed at ${DEST}"
  ls "${DEST}" | head
  exit 0
fi

mkdir -p "${HOME}/.local/share/godot/export_templates"
TMP="/tmp/${TPZ_NAME}"
if [[ ! -f "${TMP}" ]]; then
  ok=0
  for u in "${URLS[@]}"; do
    echo "Downloading ${u}"
    if wget -q --show-progress -O "${TMP}" "${u}"; then
      ok=1
      break
    fi
  done
  if [[ "${ok}" -ne 1 ]]; then
    echo "Download failed" >&2
    exit 1
  fi
fi

EXTRACT="/tmp/godot_templates_extract_$$"
rm -rf "${EXTRACT}"
mkdir -p "${EXTRACT}"
unzip -q "${TMP}" -d "${EXTRACT}"
rm -rf "${DEST}"
if [[ -d "${EXTRACT}/templates" ]]; then
  mv "${EXTRACT}/templates" "${DEST}"
else
  mkdir -p "${DEST}"
  mv "${EXTRACT}"/* "${DEST}/" || true
fi
rm -rf "${EXTRACT}"
echo "Installed → ${DEST}"
ls "${DEST}" | head -20
