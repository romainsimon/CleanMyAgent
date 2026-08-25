# Agent Space Design Direction

## Mode

Operate. The interface exists for fast diagnosis and careful maintenance, not promotion.

## Visual authority

Agent Space extends the visual language already approved for the Codex storage dashboard: near-black layered surfaces, quiet separators, compact rows, white primary type, gray secondary type, and sparse blue status accents. macOS navigation, menus, toolbars, window behavior, focus, and accessibility remain native.

## Reference synthesis

- Codex storage dashboard: borrow its restrained table density, numeric alignment, and absence of decorative chrome.
- Cursor desktop workspace: borrow the predictable left-to-right navigation and clear division between task list and detail surface.
- Apple native utility conventions: borrow the menu-bar summary, toolbar refresh action, selection behavior, keyboard access, and system materials.
- The Okara dashboard was reviewed as an anti-reference for this product: its multi-panel command-center density would make a safety utility harder to scan.

## Structure

- A compact sidebar contains Overview, Agents, Performance, Storage, Worktrees, and Settings.
- The detail surface uses one primary table or list per screen rather than grids of repeated cards.
- Overview leads with a plain-language disk status, then agent rows and current performance evidence.
- A menu-bar item provides free space and audit status without duplicating the full application.

## Color and material

- Window base: neutral near-black.
- Sidebar: native macOS material with reduced-transparency fallback.
- Rows: transparent until hover or selection; separators carry structure.
- Blue: selected navigation and healthy informational emphasis.
- Amber: low-space warning.
- Red: critical disk pressure or scan failure only.
- Agent colors identify source, never safety state.

## Typography

Use San Francisco through SwiftUI system styles. Measurements use monospaced digits, not a monospaced interface costume. Hierarchy comes from weight, size, and spacing.

## Motion

No ornamental motion. Refresh and progress changes use native, interruptible feedback. Reduced Motion removes nonessential transitions.

## Safety language

Name the source, scope, last refresh time, and coverage. Do not call observed throughput provider speed. The MVP states “Read-only audit” anywhere a user might otherwise expect a cleaning action.
