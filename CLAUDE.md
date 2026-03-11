# Focus — Project CLAUDE.md

> A Mac menu bar app that tracks what you're working on across AI coding sessions.

## Session Summary — Tue Mar 10, 2026

### What was done
- Committed `install.sh` fix: changed install target from `/usr/local/bin` to `~/.local/bin` (no more sudo needed)
- Updated README.md to match the new install path
- Fixed stale comment in install.sh

### What's unfinished
- The commit is **not pushed** to origin (main is 1 ahead). Push when ready.

### What's next
- Push the install fix to origin
- Consider adding `~/.local/bin` to PATH check/warning in the installer (some systems don't have it in PATH by default)
- The project is early (3 commits total). Next feature work TBD.

### Shiny Things Box
- (empty — no deferred ideas this session)

---

## Project Notes

- **Stack:** Swift (menu bar app) + Bun/TypeScript (MCP server)
- **Build:** `swift build -c release`
- **MCP server:** lives in `mcp-server/`, installed via `bun install`
- **Install:** `./install.sh` — idempotent, configures Claude Code and OpenCode automatically
- **Binary location:** `~/.local/bin/focus`
- **Repo:** github.com/CestDiego/focus
