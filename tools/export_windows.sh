#!/usr/bin/env bash
# Exporta o jogo para Windows (x86_64) em build/ArcaneArena.exe — um único arquivo, com o .pck embutido.
# Baixa os templates de exportação do Godot na primeira vez (download de ~1,2 GB; só os de Windows ficam).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="4.6-stable"
TEMPLATES="$HOME/.local/share/godot/export_templates/4.6.stable"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
if [ ! -f "$TEMPLATES/windows_release_x86_64.exe" ]; then
  TMP="$(mktemp -d)"
  curl -fsSL -o "$TMP/templates.tpz" \
    "https://github.com/godotengine/godot/releases/download/$VERSION/Godot_v${VERSION}_export_templates.tpz"
  mkdir -p "$TEMPLATES"
  unzip -oqj "$TMP/templates.tpz" "templates/version.txt" "templates/windows_*_x86_64*.exe" -d "$TEMPLATES"
  rm -rf "$TMP"
fi
mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows" build/ArcaneArena.exe
test -s build/ArcaneArena.exe
ls -la build/ArcaneArena.exe
