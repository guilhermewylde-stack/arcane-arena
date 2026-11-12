#!/usr/bin/env bash
# Instala o Godot usado pelo projeto em ~/.local/bin/godot (Linux x86_64). Idempotente.
set -euo pipefail
VERSION="4.6-stable"
DEST="$HOME/.local/bin"
if [ -x "$DEST/godot" ] && "$DEST/godot" --version | grep -q "^4.6.stable"; then
  echo "Godot já instalado: $("$DEST/godot" --version)"; exit 0
fi
mkdir -p "$DEST"
TMP="$(mktemp -d)"
curl -fsSL -o "$TMP/godot.zip" \
  "https://github.com/godotengine/godot/releases/download/$VERSION/Godot_v${VERSION}_linux.x86_64.zip"
unzip -oq "$TMP/godot.zip" -d "$TMP"
mv "$TMP/Godot_v${VERSION}_linux.x86_64" "$DEST/godot"
rm -rf "$TMP"
echo "Instalado: $("$DEST/godot" --version)"
