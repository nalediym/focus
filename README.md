# Focus

A Mac menu bar app that tracks what you're working on across all your AI coding sessions.

Every coding session (Claude Code, OpenCode, Cursor, etc.) registers its current project, goal, and task list via MCP. Focus aggregates everything into a single glanceable indicator so you always know what's active, what's next, and whether you're drifting.

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/CestDiego/focus/main/install.sh | bash
```

This will:
1. Clone the repo to `~/Projects/focus`
2. Build the Swift menu bar app
3. Install the MCP server
4. Auto-configure Claude Code and OpenCode (if installed)
5. Install the binary to `~/.local/bin/focus`

Then run it:
```bash
focus
```

> **Requires:** macOS 13+, Xcode CLT (`xcode-select --install`), [Bun](https://bun.sh)

---

## For AI Agents

If you are an AI coding agent reading this to set up Focus for your user, here is exactly what to do:

### Step 1: Install

Run this single command in the terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/CestDiego/focus/main/install.sh | bash
```

If the repo is already cloned, run `./install.sh` from the project root instead.

The installer is idempotent — safe to run multiple times.

### Step 2: Launch

```bash
focus &
```

Or if not in PATH: `~/Projects/focus/.build/release/Focus &`

### Step 3: Use the MCP tools in your session

After install, you have these tools available via MCP:

| Tool | When to call it |
|---|---|
| `focus_session_start` | At the start of a coding session. Pass `projectDir`, `goal`, `why`, `source`. |
| `focus_tasks_sync` | Whenever your task list changes. Pass `projectDir` and `tasks` array. |
| `focus_session_end` | When work is done. Pass `projectDir` and `reason` (completed/abandoned/redefined). |
| `focus_mode_set` | When you detect the user may be unfocused. Pass `mode` and `reason`. |
| `focus_status` | To see all active sessions. Call this to check if the user is drifting. |

### Step 4: Keep it updated

Call `focus_tasks_sync` whenever you update your internal todo list. The menu bar refreshes automatically.

Call `focus_session_start` at the beginning of each session with the project directory and a clear goal.

Call `focus_status` periodically to check if there are too many active sessions (the user may be context-switching too much).

---

## How It Works

```
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   Claude Code    │  │    OpenCode       │  │  Any MCP Client  │
│   (PostToolUse   │  │   (plugin hook    │  │                  │
│    hook + MCP)   │  │    + MCP)         │  │   (MCP only)     │
└────────┬─────────┘  └────────┬──────────┘  └────────┬─────────┘
         │                     │                       │
         ▼                     ▼                       ▼
    ┌────────────────────────────────────────────────────────┐
    │              ~/.config/focus/focus.db                   │
    │              (SQLite · WAL mode)                        │
    └────────────────────────┬───────────────────────────────┘
                             │
                             ▼
                  ┌────────────────────────┐
                  │  Focus (menu bar)      │
                  │  🟢 2 sessions         │
                  └────────────────────────┘
```

Multiple coding sessions write to the same SQLite database. The menu bar app polls it every 2 seconds and displays all active sessions with their tasks, grouped by source.

## MCP Tools Reference

### `focus_session_start`

Register or resume a focus session.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `projectDir` | string | yes | Absolute path to the project |
| `goal` | string | no | What you're trying to accomplish |
| `why` | string | no | Why this work matters |
| `trigger` | string | no | What triggered this session |
| `source` | string | no | Client ID: `claude-code`, `opencode`, `cursor` |
| `sourceSessionId` | string | no | The client's own session ID |

### `focus_tasks_sync`

Replace the task list for a session.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `projectDir` | string | yes | Absolute path to the project |
| `sourceSessionId` | string | no | Client session ID for matching |
| `tasks` | array | yes | `[{content, status, priority?}]` |

Status values: `pending`, `in_progress`, `completed`  
Priority values: `high`, `medium`, `low`

### `focus_session_end`

End a focus session.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `projectDir` | string | yes | Absolute path to the project |
| `sourceSessionId` | string | no | Client session ID |
| `reason` | enum | yes | `completed`, `abandoned`, or `redefined` |

### `focus_mode_set`

Set the user's cognitive mode.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `mode` | enum | yes | `focused`, `grounding`, or `unfocused` |
| `reason` | string | no | Human-readable reason |

### `focus_status`

Returns JSON with all active sessions, current mode, and last mood. Takes no parameters.

## Cognitive Modes

| Mode | Icon | Meaning |
|---|---|---|
| **Focused** | 🟢 | Actively working, clear goal, making progress |
| **Grounding** | 🟡 | Transitioning to focus — addressing blockers, managing energy |
| **Unfocused** | ◌ | Drifting, fatigued, or between sessions |

The popover includes mood check-in buttons (good / meh / stuck / redefine). Self-reports influence the displayed mode.

## Manual Configuration

If you prefer not to use the installer:

### MCP Server

**Claude Code** — `~/.claude/mcp.json`:
```json
{
  "mcpServers": {
    "focus": {
      "command": "bun",
      "args": ["run", "/path/to/focus/mcp/index.ts"]
    }
  }
}
```

**OpenCode** — `~/.config/opencode/opencode.json`:
```json
{
  "mcp": {
    "focus": {
      "type": "local",
      "command": ["bun", "run", "/path/to/focus/mcp/index.ts"]
    }
  }
}
```

### Claude Code Hook (automatic TodoWrite sync)

```bash
cp scripts/sync-tasks.py ~/.claude/hooks/sync-tasks.py
```

Add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "TodoWrite",
      "hooks": [{"type": "command", "command": "python3 ~/.claude/hooks/sync-tasks.py", "timeout": 5}]
    }]
  }
}
```

### OpenCode Plugin (automatic todowrite sync)

```bash
mkdir -p ~/.config/opencode/plugin
cp scripts/opencode-plugin.ts ~/.config/opencode/plugin/focus.ts
```

## Architecture

```
focus/
├── Package.swift                 # Swift Package Manager
├── install.sh                    # One-command installer
├── Sources/Focus/
│   ├── main.swift                # Entry point
│   ├── AppDelegate.swift         # Menu bar + popover
│   ├── Store.swift               # GRDB · SQLite · models · queries
│   ├── ModeEngine.swift          # Rules-based mode inference
│   └── ContentView.swift         # SwiftUI popover (multi-session)
├── mcp/
│   ├── package.json              # MCP server deps
│   └── index.ts                  # MCP server (5 tools, bun:sqlite)
└── scripts/
    ├── sync-tasks.py             # Claude Code PostToolUse hook
    └── opencode-plugin.ts        # OpenCode plugin
```

**Database:** `~/.config/focus/focus.db` — SQLite with WAL mode, shared across all processes.

**Tables:** `sessions` (source, goal, why, phase), `tasks` (per-session), `mode_log`, `self_reports`

## Run on Login

```bash
# Build release
swift build -c release

# Copy binary
mkdir -p ~/.local/bin
cp .build/release/Focus ~/.local/bin/focus

# Add to Login Items
# System Settings → General → Login Items → add "focus"
```

## License

MIT
