# CleanMyAgent

Native macOS 14+ SwiftUI utility. Read PRODUCT.md and DESIGN.md before product changes. Preserve unrelated work. Use a codex/ branch from current origin/main and a PR for delivery.

## Commands
- Tests: `swift test`
- Universal local bundle: `./scripts/build-app.sh`
- Standalone final-artifact validation: `./scripts/runtime-smoke.sh`
- Demo UI: `dist/CleanMyAgent.app/Contents/MacOS/CleanMyAgent --demo` (public fixtures, cleanup disabled)
- Public signing: set `CLEANMYAGENT_SIGNING_IDENTITY` to an installed Developer ID identity. Notarization is a separate release state.

## Boundaries
Services scan local numeric metadata, filesystem and Git evidence. Never index or upload conversation content. Unknown Git, PR, process or ignored-file evidence protects a worktree. Refresh evidence immediately before each cleanup item. Unique ignored contents stay protected; directories require review. Worktree removal uses Git without force, while cache/dependency/archive actions use macOS Trash. Do not run cleanup against real user data during QA.

## Visual ship bar
Use Impeccable once per UI milestone and preserve the native midnight identity. Inspect the copied app at normal and minimum window sizes, with keyboard navigation, sidebar toggles, range changes, close/reopen and confirmation cancellation. Native accessibility labels and reduced motion remain required. Per the user's 2026-09-27 request, publication screenshots use --screenshots without an in-image “Demo data” label; disclose example values in the surrounding page caption. Both capture modes must keep live scans and cleanup disabled.

## Release
Test the exact candidate's copied standalone bundle outside the checkout with fixture credentials. CI must run Production runtime smoke. Verify both architectures, package resources, signature and downloaded artifact. State signing and notarization separately. Keep release assets recoverable. Version is in VERSION.
