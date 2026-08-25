# Agent Space

Agent Space is a native macOS dashboard for local coding-agent storage, Git worktrees, and observable performance.

The first MVP supports:

- Codex, Claude Code, and Grok storage totals and categories;
- free disk capacity and pressure status;
- a read-only Git worktree inventory;
- a live Codex observed-token speedometer, refreshed every second;
- local token, TTFT, response-time, and observed-throughput metadata;
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

Version 0.1 is audit-only. It does not delete or modify sessions, caches, dependencies, repositories, branches, or worktrees.
