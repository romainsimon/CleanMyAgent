# Agent Space

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

The first and currently confirmed product is a native macOS application.

## Stack

SwiftUI and Swift Package Manager. The choice was proposed with the MVP and accepted when the user asked to start the new project.

## Users

The primary user runs several local coding agents and many Git projects on one Mac. They need to understand disk pressure quickly, identify which agent or project owns storage, and compare agent performance without opening each tool separately.

## Product Purpose

Agent Space provides one local control surface for Codex, Claude Code, Grok, Git worktrees, and agent performance. Success means the user can identify storage pressure and performance changes without reading raw session files or risking active work.

## Positioning

Unlike an agent-specific plugin, Agent Space uses local adapters to present storage, worktrees, and performance for several coding agents in one privacy-preserving macOS application.

## Operating Context

- Agent data lives under `~/.codex`, `~/.claude`, and `~/.grok`.
- Projects and temporary worktrees are primarily under `/Users/romainsimon/dev`.
- The application must remain useful when an agent UI is closed.
- Measurements come from local structured metadata and native agent commands when available.

## Capabilities and Constraints

- The MVP audits disk usage, free capacity, agent storage, Git worktrees, locally observable speed metrics, and bounded local usage history by day, agent, model, and token category.
- The MVP is read-only. It does not delete caches, sessions, dependencies, or worktrees.
- Performance labels must distinguish observed output throughput, TTFT, end-to-end duration, token counts, and partial coverage.
- Future cleaning actions must preserve dirty, active, unmerged, unknown, and open-PR worktrees.
- Future agent integrations can use a local MCP server, but that server is not part of the first MVP.
- Cross-agent comparisons are shown only for metrics that each adapter can support honestly.

## Brand Commitments

- Product name: Agent Space.
- The application should feel close to Codex while using native macOS structure and controls.
- The tone is calm, specific, and operational. It does not exaggerate precision or safety.

## Evidence on Hand

- The existing Codex Disk Space Management plugin contains the original audit and conservative cleaning rules.
- The existing Codex Speedometer contains the observed throughput definition and privacy model.
- Local Claude Code JSONL records expose duration, model, token, and cache metadata.
- Local Grok sessions expose token context, TTFT, response latency, inter-token latency, and native disk/worktree commands.
- No cross-agent provider-side decoding-speed API is available; the product must label local observations accordingly.

## Product Principles

1. Audit before action.
2. Preserve active work by default.
3. Show provenance and coverage for every metric.
4. Index numbers and opaque identifiers, never conversation content.
5. Prefer native agent and Git lifecycle commands over raw deletion.

## Accessibility & Inclusion

Use native macOS accessibility, keyboard navigation, Dynamic Type behavior where available, sufficient contrast, reduced motion, and reduced transparency.
