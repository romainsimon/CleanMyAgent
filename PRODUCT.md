# CleanMyAgent

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

The first and currently confirmed product is a native macOS application.

## Stack

SwiftUI and Swift Package Manager. The choice was proposed with the MVP and accepted when the user asked to start the new project.

## Users

The primary user runs several local coding agents and many Git projects on one Mac. They need to understand disk pressure quickly, identify which agent or project owns storage, and compare agent performance without opening each tool separately.

## Product Purpose

CleanMyAgent provides one local control surface for Codex, Claude Code, Grok, Git worktrees, and agent performance. Success means the user can identify storage pressure and performance changes without reading raw session files or risking active work.

## Positioning

Unlike an agent-specific plugin, CleanMyAgent uses local adapters to present storage, worktrees, and performance for several coding agents in one privacy-preserving macOS application.

## Operating Context

- Agent data lives under `~/.codex`, `~/.claude`, `~/.grok`, `~/.cursor`, `~/.hermes`, `~/.local/share/opencode`, `~/.ori`, and related macOS application-support folders.
- Projects and temporary worktrees are discovered under the current user's configurable development root (currently `~/dev`).
- The application must remain useful when an agent UI is closed.
- Measurements come from local structured metadata and native agent commands when available.

## Capabilities and Constraints

- The application audits disk usage, free capacity, agent storage, Git worktrees, attributable process memory, locally observable speed metrics, and bounded local usage history by day, agent, model, token category, and provider-reported cost.
- Installed adapters cover Codex, Claude Code, Grok Build, Cursor, Hermes Agent, OpenCode, Ori, and Kilo Code. Each adapter declares the metrics its local format can support.
- Archived Codex sessions can be moved to the macOS Trash after an explicit confirmation, then the empty archive folder is recreated.
- Worktree cleanup is selective and uses `git worktree remove`, never raw directory deletion. A target is eligible only when it is inactive, unlocked, clean, has no untracked or unpushed work, and is verified in the default branch or at the exact remote head of a merged pull request. Every target is revalidated immediately before removal. Repository branches and pull requests are not deleted.
- Active sessions, caches, dependencies, repositories, branches, active worktrees, dirty worktrees, open-PR worktrees, unmerged worktrees, and unknown worktrees remain protected.
- Performance labels must distinguish observed output throughput, TTFT, end-to-end duration, token counts, and partial coverage.
- Future agent integrations can use a local MCP server, but that server is not part of the first MVP.
- Cross-agent comparisons are shown only for metrics that each adapter can support honestly.

## Brand Commitments

- Product name: CleanMyAgent.
- The application should feel close to Codex while using native macOS structure and controls.
- The tone is calm, specific, and operational. It does not exaggerate precision or safety.

## Evidence on Hand

- The existing Codex Disk Space Management plugin contains the original audit and conservative cleaning rules.
- The existing Codex Speedometer contains the observed throughput definition and privacy model.
- Local Claude Code JSONL records expose duration, model, token, and cache metadata.
- Local Grok sessions expose token context, TTFT, response latency, inter-token latency, and native disk/worktree commands.
- Local OpenCode and Hermes SQLite databases expose session, model, token, cache, and recorded-cost totals.
- Ori records launcher history for underlying agents, so its token totals must not be aggregated a second time.
- Cursor and Kilo Code expose useful storage and worktree state but no stable local token-speed source.
- No cross-agent provider-side decoding-speed API is available; the product must label local observations accordingly.

## Product Principles

1. Audit before action.
2. Preserve active work by default.
3. Show provenance and coverage for every metric.
4. Index numbers and opaque identifiers, never conversation content.
5. Prefer reversible system actions and native agent or Git lifecycle commands over raw deletion.

## Accessibility & Inclusion

Use native macOS accessibility, keyboard navigation, Dynamic Type behavior where available, sufficient contrast, reduced motion, and reduced transparency.
