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
- Copied standalone runtime smoke passes, including loading each navigation glyph and all nine illustrations, Git audit and ignored-file protection.
- All 28 exported glyphs contain both full foreground and the 20% secondary alpha.
- Impeccable context and colorize/Operate/craft-floor guidance used. Its HTML/CSS detector has no native SwiftUI verdict; native review remains required.

## Remaining visual gate

Native UI automation reported the Mac locked and automatic unlock suspended after physical input. Romain was asked to unlock it. Normal/minimum window inspection, both appearances, native preference interaction, keyboard/Reduce Motion and confirmation cancellation are pending. Do not infer those checks from the website simulation or automated smoke. This PR remains draft until that gate is complete. No production merge or deployment is included.
