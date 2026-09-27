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

## Remaining visual gate

A first native pass confirmed the Light palette and shared Settings/sidebar preference, but exposed blank glyphs and illustrations when SwiftUI loaded the package assets by name. Loading explicit NSImages from the module bundle fixes that path; the renderer and smoke check share it. The Mac locked again during the candidate restart, so final visual confirmation of the images, all eight views in both themes, normal/minimum windows, keyboard/Reduce Motion and confirmation cancellation is pending a user unlock. Do not infer those checks from the website simulation or automated smoke. This PR remains draft until that gate is complete. No production merge or deployment is included.
