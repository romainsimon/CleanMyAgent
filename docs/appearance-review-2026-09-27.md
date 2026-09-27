# Light and dark appearance refinement

User brief: improve the Mac app, add light/dark palettes, use the same Phosphor Duotone icons as the website, and include the existing illustration family. This builds on PR #10's layout and motion, without changing audit, scanner or cleanup rules.

## Implementation

- System (default), Light and Dark appearances persist through AppStorage; the sidebar and Settings control the same preference.
- Independent white/warm-neutral and charcoal palettes, coral navigation/action, readable semantic green/amber/red, theme-aware chart categories, hover, tracks and scrollbar styling.
- Official Phosphor Core 2.1.1 Duotone PNG templates preserve the original glyph paths and 20% secondary alpha. SVG sources, package provenance and MIT license are bundled. Native window toolbar controls and checkboxes keep their OS conventions.
- Nine existing transparent image_gen illustrations are packaged locally. Headers and cleanup groups use them decoratively; exact evidence and paths retain priority. Actual agent logos stay intact; Ori uses the same branch fallback as the website.
- Existing pointer/keyboard/reduced-motion policies remain unchanged. Appearance switches immediately.

## Evidence

- 35 tests pass: 5 XCTest checks (including palette contrast, native dynamic appearance resolution and saved preferences) and 30 existing safety/parser/process checks.
- Every text/action/status role meets 4.5:1 on its applicable canvas, card and selection surfaces. Light coral and amber were darkened after the contrast test found two selected-surface failures.
- Universal arm64/x86_64 bundle builds and Developer ID signature verifies. No new notarization or public release is claimed.
- Copied standalone and unpacked ZIP runtime smoke pass, including loading each navigation glyph and all nine illustrations, Git audit and ignored-file protection. The renderer and smoke check now use the same explicit native image loader.
- GitHub Actions Swift tests and production runtime smoke pass at 50437de2ee71e6baf5d5cb1f2923978574192685 (run 36336973991).
- All 28 exported glyphs contain both full foreground and the 20% secondary alpha.
- Impeccable context and colorize/Operate/craft-floor guidance used. Its HTML/CSS detector has no native SwiftUI verdict; native review remains required.

## Native visual evidence

The Mac became available. At code revision 28c7017, all eight native pages were inspected in Light and Dark at a normal 1102pt width and key views at the 940pt minimum content width. Native body minimum height is 620pt; screenshots also include the 52pt toolbar. Glyphs and illustrations render, both appearance controls agree, System resolves to the Mac appearance, and Dark persists through a fixture-process relaunch.

The review exposed two bundle/image issues: SwiftUI name-based asset lookup produced blank images, and an AppKit segmented picker used the 128px intrinsic image size instead of the SwiftUI frame. The renderer now loads explicit NSImages, sets each glyph's intrinsic point size and template flag, and shares that path with the standalone smoke check. The sidebar begins with navigation; no logo, app name or tagline remains. The --demo cleanup warning stays in the footer.

Usage 7/30/90-day controls update totals and charts. Protected worktree selection remains disabled. Both themed confirmations list the two public fixture worktrees, keep their acknowledgement unchecked and final action disabled, and were cancelled without removal. Sidebar hide/show works. The --reduce-motion candidate was inspected with settled charts; the keyboard/reduced-motion policy test also passes. Public captures use --screenshots without an in-image Demo data label, with example data disclosed outside the image.

## Remaining interaction gate

The keyboard Show Window command opened an additional WindowGroup window. Closing the test window left the process running, but CUA then timed out while trying to bind the windowless state. A fixture-process relaunch succeeded; this does not prove direct menu/keyboard reopening after the last window closes. A Tab/Right focus probe also left focus on the window; full keyboard traversal remains unconfirmed, and no Mac keyboard-navigation setting was changed. Keep the app PR draft for those two manual interaction checks. No production merge or public release is included.
