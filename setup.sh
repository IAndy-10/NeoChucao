#!/usr/bin/env bash
# NeoChucao setup: everything needed to play the RAVE latent space by MIDI or by language.
#
#   ./setup.sh            both modes: nn.ar + birds.ts + ClaudeCollider (submodule)
#   ./setup.sh --midi     MIDI mode only: skip ClaudeCollider and Node.js
#   ./setup.sh --extras   also download marinemammals.ts for examples/
#
# Flags can be combined. Safe to re-run: each step is skipped when it is already done.
set -euo pipefail

MIDI_ONLY=0
EXTRAS=0
for arg in "$@"; do
  case "$arg" in
    --midi)   MIDI_ONLY=1 ;;
    --extras) EXTRAS=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODELS="$ROOT/models"
CC_DIR="$ROOT/agent/claude-collider"
HF="https://huggingface.co/Intelligent-Instruments-Lab/rave-models/resolve/main"
NN_AR_VERSION="v0.0.8-alpha"

case "$(uname)" in
  Darwin) EXTENSIONS="$HOME/Library/Application Support/SuperCollider/Extensions" ;;
  *)      EXTENSIONS="${XDG_DATA_HOME:-$HOME/.local/share}/SuperCollider/Extensions" ;;
esac

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()   { printf '    ok: %s\n' "$1"; }
die()  { printf '\n    error: %s\n' "$1" >&2; exit 1; }

# ── 1. Prerequisites ────────────────────────────────────────────
step "Checking prerequisites"
if [[ "$(uname)" == Darwin ]]; then
  [[ -x /Applications/SuperCollider.app/Contents/MacOS/sclang ]] || command -v sclang >/dev/null \
    || die "SuperCollider not found. Install it from https://supercollider.github.io"
else
  command -v sclang >/dev/null || die "sclang not found. Install SuperCollider first."
fi
ok "SuperCollider"
if (( ! MIDI_ONLY )); then
  command -v node >/dev/null || die "Node.js 18+ is required for agent mode (https://nodejs.org). For MIDI mode only, run ./setup.sh --midi"
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
  (( NODE_MAJOR >= 18 )) || die "Node.js 18+ is required for agent mode (found $(node -v)). For MIDI mode only, run ./setup.sh --midi"
  ok "Node.js $(node -v)"
fi

# ── 2. ClaudeCollider (git submodule, agent mode only) ──────────
if (( MIDI_ONLY )); then
  step "ClaudeCollider: skipped (--midi)"
else
  step "ClaudeCollider MCP server (agent/claude-collider)"
  git -C "$ROOT" submodule update --init --recursive
  # ClaudeCollider's own setup symlinks its quark into Extensions. Refuse to
  # replace a real folder there (an existing non-symlink install).
  if [[ -e "$EXTENSIONS/ClaudeCollider" && ! -L "$EXTENSIONS/ClaudeCollider" ]]; then
    die "$EXTENSIONS/ClaudeCollider is a real folder, not a symlink. Move it away and re-run."
  fi
  "$CC_DIR/setup.sh"
  ok "quark linked, server built at agent/claude-collider/dist/index.js"
fi

# ── 3. nn.ar (RAVE inference UGen) ──────────────────────────────
step "nn.ar SuperCollider extension"
if [[ -d "$EXTENSIONS/nn.ar" ]]; then
  ok "already installed"
else
  case "$(uname)-$(uname -m)" in
    Darwin-arm64)  ASSET="nn.ar-macOS-latest-arm64.zip" ;;
    Darwin-x86_64) ASSET="nn.ar-macOS-13-x64.zip" ;;
    Linux-x86_64)  ASSET="nn.ar-Linux-x64.zip" ;;
    *) die "No nn.ar build for $(uname)-$(uname -m). See https://github.com/elgiano/nn.ar" ;;
  esac
  TMP="$(mktemp -d)"
  curl -fL --progress-bar -o "$TMP/nn.ar.zip" \
    "https://github.com/elgiano/nn.ar/releases/download/$NN_AR_VERSION/$ASSET"
  unzip -q "$TMP/nn.ar.zip" -d "$TMP/unzipped"
  SRC="$(find "$TMP/unzipped" -maxdepth 2 -type d -name 'nn.ar' | head -1)"
  [[ -n "$SRC" ]] || SRC="$TMP/unzipped"
  mkdir -p "$EXTENSIONS"
  cp -R "$SRC" "$EXTENSIONS/nn.ar"
  rm -rf "$TMP"
  ok "installed $NN_AR_VERSION ($ASSET)"
fi

# ── 4. RAVE models ──────────────────────────────────────────────
fetch_model() { # <local name> <hugging face file>
  local dest="$MODELS/$1"
  if [[ -s "$dest" ]]; then ok "$1 already present"; return; fi
  echo "    downloading $2 -> models/$1"
  curl -fL --progress-bar -o "$dest.part" "$HF/$2"
  mv "$dest.part" "$dest"
  ok "$1"
}

step "RAVE models (models/)"
mkdir -p "$MODELS"
fetch_model birds.ts birds_motherbird_b2048_r48000_z16.ts
if (( EXTRAS )); then
  fetch_model marinemammals.ts marinemammals_pondbrain_b2048_r48000_z20.ts
fi

# ── Done ────────────────────────────────────────────────────────
cat <<EOF

Setup complete. Restart SuperCollider (or recompile the class library) so it
picks up the extensions.

Choose one mode per session (they do not run together):
  MIDI mode:   open midi/rave_midi_filter.scd and run blocks 1 -> 2 -> 3
EOF
if (( MIDI_ONLY )); then
  echo "  Agent mode:  skipped (--midi). Run ./setup.sh without --midi to set it up."
else
  echo "  Agent mode:  cd agent && claude     (then follow agent/README.md, \"Session order\")"
fi
