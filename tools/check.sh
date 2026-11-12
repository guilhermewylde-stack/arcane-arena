#!/usr/bin/env bash
# Verificação obrigatória antes de todo commit: importa o projeto e roda os testes.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
OUT="$("$GODOT" --headless --path . --import 2>&1)" || { echo "$OUT"; exit 1; }
if echo "$OUT" | grep -E "SCRIPT ERROR|Parse Error"; then exit 1; fi
"$GODOT" --headless --path . -s tests/run_tests.gd
