#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Focus — one-command installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CestDiego/focus/main/install.sh | bash
#
# Or if already cloned:
#   ./install.sh
# ─────────────────────────────────────────────────────────

FOCUS_DIR="${FOCUS_DIR:-$HOME/Projects/focus}"
REPO="https://github.com/CestDiego/focus.git"

info()  { printf "\033[0;34m▸\033[0m %s\n" "$*"; }
ok()    { printf "\033[0;32m✓\033[0m %s\n" "$*"; }
warn()  { printf "\033[0;33m!\033[0m %s\n" "$*"; }
fail()  { printf "\033[0;31m✗\033[0m %s\n" "$*"; exit 1; }

# ── prerequisites ────────────────────────────────────────

info "Checking prerequisites..."

command -v swift >/dev/null 2>&1 || fail "Swift not found. Install Xcode CLT: xcode-select --install"
command -v bun   >/dev/null 2>&1 || fail "Bun not found. Install: curl -fsSL https://bun.sh/install | bash"
command -v git   >/dev/null 2>&1 || fail "Git not found."

ok "swift, bun, git — all present"

# ── clone or update ──────────────────────────────────────

if [ -d "$FOCUS_DIR/.git" ]; then
  info "Updating $FOCUS_DIR..."
  git -C "$FOCUS_DIR" pull --ff-only 2>/dev/null || true
else
  info "Cloning to $FOCUS_DIR..."
  mkdir -p "$(dirname "$FOCUS_DIR")"
  git clone "$REPO" "$FOCUS_DIR"
fi

cd "$FOCUS_DIR"

# ── build swift app ──────────────────────────────────────

info "Building Focus menu bar app..."
swift build -c release 2>&1 | tail -1
ok "Built .build/release/Focus"

# ── install MCP deps ─────────────────────────────────────

info "Installing MCP server dependencies..."
(cd mcp && bun install --silent 2>/dev/null)
ok "MCP server ready"

# ── install to ~/.local/bin ────────────────────────────

info "Installing binary to ~/.local/bin/focus..."
mkdir -p "$HOME/.local/bin"
cp .build/release/Focus "$HOME/.local/bin/focus" 2>/dev/null || {
  warn "Cannot write to ~/.local/bin"
}
ok "Installed: ~/.local/bin/focus"

# ── configure MCP: Claude Code ───────────────────────────

CLAUDE_MCP="$HOME/.claude/mcp.json"
MCP_CMD="bun"
MCP_ARG="run"
MCP_PATH="$FOCUS_DIR/mcp/index.ts"

configure_claude_code() {
  mkdir -p "$HOME/.claude"
  if [ -f "$CLAUDE_MCP" ]; then
    if grep -q '"focus"' "$CLAUDE_MCP" 2>/dev/null; then
      ok "Claude Code MCP already configured"
      return
    fi
    # merge into existing config
    python3 -c "
import json, sys
p = '$CLAUDE_MCP'
with open(p) as f: cfg = json.load(f)
cfg.setdefault('mcpServers', {})['focus'] = {
    'command': '$MCP_CMD',
    'args': ['$MCP_ARG', '$MCP_PATH']
}
with open(p, 'w') as f: json.dump(cfg, f, indent=2)
print('ok')
" && ok "Claude Code MCP configured: $CLAUDE_MCP"
  else
    cat > "$CLAUDE_MCP" <<EOF
{
  "mcpServers": {
    "focus": {
      "command": "$MCP_CMD",
      "args": ["$MCP_ARG", "$MCP_PATH"]
    }
  }
}
EOF
    ok "Claude Code MCP configured: $CLAUDE_MCP"
  fi
}

# ── configure MCP: OpenCode ──────────────────────────────

OPENCODE_CFG="$HOME/.config/opencode/opencode.json"

configure_opencode() {
  if [ ! -f "$OPENCODE_CFG" ]; then
    warn "OpenCode config not found at $OPENCODE_CFG — skipping"
    return
  fi
  if grep -q '"focus"' "$OPENCODE_CFG" 2>/dev/null; then
    ok "OpenCode MCP already configured"
    return
  fi
  python3 -c "
import json
p = '$OPENCODE_CFG'
with open(p) as f: cfg = json.load(f)
cfg.setdefault('mcp', {})['focus'] = {
    'type': 'local',
    'command': ['$MCP_CMD', '$MCP_ARG', '$MCP_PATH']
}
with open(p, 'w') as f: json.dump(cfg, f, indent=2)
print('ok')
" && ok "OpenCode MCP configured: $OPENCODE_CFG"
}

# ── configure Claude Code hook ───────────────────────────

configure_claude_hook() {
  mkdir -p "$HOME/.claude/hooks"
  cp "$FOCUS_DIR/scripts/sync-tasks.py" "$HOME/.claude/hooks/sync-tasks.py"
  chmod +x "$HOME/.claude/hooks/sync-tasks.py"

  SETTINGS="$HOME/.claude/settings.json"
  if [ -f "$SETTINGS" ] && grep -q "sync-tasks" "$SETTINGS" 2>/dev/null; then
    ok "Claude Code hook already configured"
    return
  fi

  if [ -f "$SETTINGS" ]; then
    python3 -c "
import json
p = '$SETTINGS'
with open(p) as f: cfg = json.load(f)
cfg.setdefault('hooks', {}).setdefault('PostToolUse', []).append({
    'matcher': 'TodoWrite',
    'hooks': [{'type': 'command', 'command': 'python3 ~/.claude/hooks/sync-tasks.py', 'timeout': 5}]
})
with open(p, 'w') as f: json.dump(cfg, f, indent=2)
print('ok')
" && ok "Claude Code PostToolUse hook configured"
  else
    warn "No ~/.claude/settings.json found — hook not configured (MCP still works)"
  fi
}

# ── configure OpenCode plugin ────────────────────────────

configure_opencode_plugin() {
  PLUGIN_DIR="$HOME/.config/opencode/plugin"
  if [ ! -d "$HOME/.config/opencode" ]; then
    warn "OpenCode not found — skipping plugin"
    return
  fi
  mkdir -p "$PLUGIN_DIR"
  cp "$FOCUS_DIR/scripts/opencode-plugin.ts" "$PLUGIN_DIR/focus.ts"
  ok "OpenCode plugin installed: $PLUGIN_DIR/focus.ts"
}

# ── run configuration ────────────────────────────────────

info "Configuring integrations..."
configure_claude_code
configure_opencode
configure_claude_hook
configure_opencode_plugin

# ── done ─────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Focus installed successfully!"
echo ""
echo "  Start it:    focus"
echo "  Or:          $FOCUS_DIR/.build/release/Focus"
echo ""
echo "  Menu bar will show: ◌ focus"
echo "  MCP tools available in your next coding session."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── optionally launch ────────────────────────────────────

if [[ "${1:-}" == "--launch" ]]; then
  info "Launching Focus..."
  pkill -f "focus" 2>/dev/null || true
  sleep 0.5
  nohup "$HOME/.local/bin/focus" >/dev/null 2>&1 &
  ok "Focus is running (PID $!)"
fi
