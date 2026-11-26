#!/usr/bin/env bash
# Render the shared shot list with Godot. Uses the display in $DISPLAY, or
# Xvfb if you pass --xvfb. Vulkan (Forward+) is tried first so clearcoat, SSR,
# and glow are real. Set GODOT to your 4.x binary if it is not the one below.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/tmp/engine-bins/Godot_v4.5.2-stable_linux.x86_64}"
OUT="${OUT:-$ROOT/engine-demos/renders/godot}"
mkdir -p "$OUT"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-godot}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" || true

RUNNER=()
if [[ "${1:-}" == "--xvfb" ]]; then
  shift
  RUNNER=(xvfb-run -a -s "-screen 0 1920x1200x24")
fi

cd "$ROOT/engine-demos/godot"

try_render() {
  local driver="$1"
  shift
  echo "Godot render with --rendering-driver ${driver}"
  "${RUNNER[@]}" "$GODOT" --path . --rendering-driver "$driver" --resolution 1600x900 -- --capture "$OUT" "$@"
}

if [[ -n "${VK_ICD_FILENAMES:-}" ]] || [[ -f /usr/share/vulkan/icd.d/lvp_icd.json ]]; then
  export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}"
  if try_render vulkan "$@"; then
    exit 0
  fi
  echo "Vulkan render failed; falling back to OpenGL compatibility."
fi

try_render opengl3 "$@"
