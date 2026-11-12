#!/usr/bin/env bash
# Teste de fumaça visual: roda o jogo de verdade e salva capturas (.png) na pasta dada.
# Na nuvem leva vários minutos (renderização por software); a janela é pequena para acelerar.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT_DIR="${1:?uso: tools/smoke.sh <pasta de saída>}"
mkdir -p "$OUT_DIR"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path . --rendering-method gl_compatibility \
  --fixed-fps 60 --resolution 1120x630 -s tests/smoke.gd -- "$OUT_DIR" 2>&1 | tee "$OUT_DIR/smoke.log" | grep -E "posição|SCRIPT ERROR|Parse Error" || true
if grep -qE "SCRIPT ERROR|Parse Error|FALHA" "$OUT_DIR/smoke.log"; then exit 1; fi
ls "$OUT_DIR"/*.png
