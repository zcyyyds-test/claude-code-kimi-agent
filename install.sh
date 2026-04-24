#!/usr/bin/env bash
# Install claude-code-kimi-agent into the user's Claude Code config (~/.claude/agents/).
# Idempotent: safe to re-run.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_AGENT="$SCRIPT_DIR/agents/kimi-agent.md"
SRC_YAML="$SCRIPT_DIR/agents/kimi-agent.read-only.yaml"

DEST_DIR="$HOME/.claude/agents"
DEST_AGENT="$DEST_DIR/kimi-agent.md"
DEST_YAML="$DEST_DIR/kimi-agent.read-only.yaml"

echo "→ checking dependencies"

if ! command -v kimi >/dev/null 2>&1; then
  echo "  ✗ kimi CLI not found on PATH"
  echo "    install from https://github.com/MoonshotAI/kimi-cli then run 'kimi login'"
  echo "    note: Kimi CLI requires an active Kimi subscription"
  exit 1
fi
echo "  ✓ kimi: $(command -v kimi)"

if command -v gtimeout >/dev/null 2>&1; then
  echo "  ✓ gtimeout: $(command -v gtimeout)"
elif command -v timeout >/dev/null 2>&1; then
  echo "  ✓ timeout: $(command -v timeout)"
else
  echo "  ✗ neither gtimeout nor timeout found"
  echo "    macOS: brew install coreutils"
  echo "    Linux: should ship with coreutils by default"
  exit 1
fi

echo "→ installing symlinks"
mkdir -p "$DEST_DIR"

link_one() {
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  = $dest (already linked)"
  elif [ -e "$dest" ]; then
    echo "  ✗ $dest exists and is NOT the expected symlink"
    echo "    move it aside or delete it, then rerun this script"
    exit 1
  else
    ln -s "$src" "$dest"
    echo "  + $dest → $src"
  fi
}

link_one "$SRC_AGENT" "$DEST_AGENT"
link_one "$SRC_YAML" "$DEST_YAML"

echo
echo "Installed. Restart Claude Code so it picks up the new subagent, then delegate like:"
echo "  Agent(subagent_type=\"kimi-agent\", prompt=\"...\", run_in_background=true)"
