#!/usr/bin/env bash
# Capture garage, custom truck, store, and trail frames with Godot 4.5.
# Uses Vulkan (Mobile renderer). Pass --xvfb when there is no display.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/tmp/engine-bins/Godot_v4.5.2-stable_linux.x86_64}"
OUT="${OUT:-/opt/cursor/artifacts}"
mkdir -p "$OUT"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-godot}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" || true
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}"

RUNNER=()
if [[ "${1:-}" == "--xvfb" ]]; then
  shift
  RUNNER=(xvfb-run -a -s "-screen 0 2100x2200x24")
fi

cd "$ROOT/godot-game"
"${RUNNER[@]}" "$GODOT" --path . --rendering-driver vulkan --audio-driver Dummy --resolution 1080x1920 -- --capture "$OUT" "$@"
