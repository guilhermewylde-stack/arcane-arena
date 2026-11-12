#!/usr/bin/env bash
# Teste de fumaça visual: roda o jogo de verdade e salva top.png e third.png na pasta dada.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT_DIR="${1:?uso: tools/smoke.sh <pasta de saída>}"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path . --rendering-method gl_compatibility \
  --fixed-fps 60 -s tests/smoke.gd -- "$OUT_DIR" 2>&1 | grep -E "posição|SCRIPT ERROR|Parse Error" || true
ls "$OUT_DIR/top.png" "$OUT_DIR/third.png"
