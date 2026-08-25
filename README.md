# Agent Space

Agent Space is a native macOS dashboard for local coding-agent storage, Git worktrees, and observable performance.

The first MVP supports:

- Codex, Claude Code, and Grok storage totals and categories;
- free disk capacity and pressure status;
- a read-only Git worktree inventory;
- a live Codex observed-token speedometer, refreshed every second;
- local token, TTFT, response-time, and observed-throughput metadata;
- ccusage-style local usage analytics with native charts by day, agent, model, and token category;
- a protected action that moves archived Codex sessions to the macOS Trash while Codex is closed;
- a menu-bar summary;
- privacy-preserving parsing that ignores prompt, response, code, and tool-output content.

## Run locally

```bash
swift run AgentSpace
```

## Tests

```bash
swift test
```

## Build a macOS application bundle

```bash
./scripts/build-app.sh
open "dist/Agent Space.app"
```

## Safety boundary

Agent Space never cleans active sessions. Its first cleanup action targets only `~/.codex/archived_sessions`, requires Codex to be closed and asks for explicit confirmation. The archive is moved to the macOS Trash, not permanently deleted. Space is reclaimed only after the user empties the Trash. Caches, dependencies, repositories, branches, and worktrees remain read-only.
