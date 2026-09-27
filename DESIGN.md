# CleanMyAgent Design Direction

## Mode and purpose

Operate. A warm, readable maintenance desk for the Mac that runs your coding agents. The first decision is what to review; exact evidence stays close to each cleanup action. The 2026-09-27 redesign keeps the native macOS structure, coral bin, San Francisco, real agent identities and every cleanup guard.

## Visual world

A lighter midnight canvas separates from neutral raised surfaces. Quiet edges replace colored outlines. Navigation uses one clear selection, official Phosphor Duotone glyphs and readable labels, without a tile behind every symbol. The app feels warm through its existing coral bin; safety colors carry evidence rather than personality.

## Color and appearance

The user requested light/dark palettes, matching Phosphor Duotone icons and illustrations on 2026-09-27; this supersedes the forced midnight and SF Symbols direction. System is the default; Light and Dark are explicit persistent choices, available in the sidebar and Settings. System follows the Mac appearance. A theme change is immediate, including under Reduce Motion.

The light palette uses a white-canvas maintenance desk with warm neutral surfaces. The dark palette uses charcoal with neutral raised surfaces; neither is a mechanical inversion. The coral selection links both to the existing smiling bin. Native system controls retain their expected structure and San Francisco typography.

| Role | Light | Dark |
|---|---|---|
| Canvas | #f7f7f5 | #151619 |
| Sidebar | #eeefed | #191b1f |
| Surface | #ffffff | #1e2024 |
| Raised | #eceeea | #292c31 |
| Text | #252832 | #f0f1f3 |
| Secondary text | #5b616a | #b0b4bc |
| Selection | #f4e3dc | #3b2b29 |
| Coral action | #a83d2c | #ff927a |
| Information / charts | #2565ac | #88b8f3 |
| Ready | #24734d | #79d8a5 |
| Protected / warning | #8d580c | #f2c579 |
| Destructive | #aa3438 | #ff9699 |

AgentPalette owns all appearances and chart categories. Text, action and semantic status labels are checked at 4.5:1 on their actual surfaces, including selection. Colors accompany readable labels and exact evidence. Progress tracks, selection, hover and scrollbar appearance also adapt; no white-on-white fallback is used.

## Icons and illustrations

Bundle the official Phosphor Core 2.1.1 Duotone SVG sources, MIT license and 128px native template exports. Original glyph paths and 20% secondary alpha remain intact, including both appearances. Authored page, navigation and evidence icons use this set; OS toolbar controls and checkboxes retain their native affordances. Actual agent identities stay their original logos; Ori uses the shared branch glyph as its fallback.

Existing transparent coral/ivory image_gen illustrations from cleanmyagent-web accompany page headers, the three cleanup families and the empty usage state. They are decorative, do not imply measurements or safety, and are hidden from accessibility. Charts, exact paths and safety reasons retain priority. Images are bundled locally, never fetched by the app.

## Typography and spacing

Use the system face. Page titles are 32pt semibold with -0.55pt tracking; secondary lines use native callout/caption with natural wrapping. Measurements use rounded system numerals and monospaced digits; free disk space is the dominant 48pt measurement. Paths use normal text except where code-shaped content earns monospace.

The 212pt sidebar uses 40pt rows and 12pt sentence-case group labels. Main content keeps 28pt outer spacing, tight related groups and 24–28pt separation between jobs. Rows use 16pt horizontal and 14pt vertical padding. Panels use continuous 14–18pt corners with one neutral edge; no decorative gradient, glow or border-plus-shadow frame.

## Information architecture

- Your Mac: Overview, Clean, Worktrees, Storage.
- Your agents: Agents, Usage, Performance.
- System: Settings.
- Overview leads with free disk space and pressure, then separate review links for worktrees and caches. They navigate; they never clean. Four largest agents and three performance observations lead to the complete dedicated screens.
- Live throughput has a compact idle state on Overview instead of a large zero-speed gauge. Full performance measurements and coverage remain on Performance.
- Worktree evidence uses a wide table when at least 700pt is available and readable stacked rows below that. Each layout retains selection, branch, path, size, state and the exact reason. The action bar wraps instead of clipping.
- Usage charts form two columns only when each chart has at least 340pt; otherwise they stack. Range controls remain native segmented pickers.
- Cleanup actions are grouped with their own sizes, eligibility and explanation. Native confirmation, target revalidation and explicit Git-versus-Trash language remain.
- One document scroll surface for long pages; the persistent Worktrees action bar stays outside it.

## Native behavior and accessibility

The minimum window remains 940×620pt. Use native toolbar controls, pickers, alerts, sheets and focus behavior. Pointer navigation uses a short transition; sidebar toggles and keyboard actions resolve immediately. Authored navigation and evidence icons use official Phosphor Core 2.1.1 Duotone, matching the interactive preview. Native window toolbar and checkbox affordances stay platform standard.

Respect Reduce Transparency with an opaque sidebar. Reduce Motion disables custom movement and settles measurements immediately. Loading retains native ProgressView feedback. Selected/disabled controls retain their semantic traits. Body text and labels remain above normal-text contrast requirements; system-disabled styling is not used as a general text color.

## Motion

The user requested more delightful app transitions and charts on 2026-09-27, superseding the earlier instant pointer-navigation direction. Pointer navigation now uses a 180ms, 6pt entry offset with opacity; a shared selection surface carries continuity between sidebar rows. Charts reveal from their baseline over 260ms, and range changes use native numeric transitions. Press feedback is 120ms with an 80ms release. The shared ease-out curve is (0.23, 1, 0.32, 1).

The input-method monitor records only mouse-versus-keyboard, never key contents or coordinates. Keyboard actions and Reduce Motion have no custom animation. Pending chart tasks cancel when their view disappears and settle when motion is disabled. Sidebar resizing, live speed updates, cleanup selection and safety checks stay immediate; confirmation retains native macOS presentation. No loop or animation library is added.

The website simulation follows these same eight destinations, hierarchy, shared light/dark tokens, native metric definitions and 7/30/90-day public fixtures. Product typography stays system-native. Usage summaries reflow at narrow window sizes; graphs stack when their labels would become cramped. Website-only adaptations include a horizontal phone navigation rail and explicit simulation disclosures.

## References and provenance

Applied official emilkowalski/skills at d16ebe60d09a5ba2afcb7054ede9d0a10c9f6128: emil-design-eng, apple-design, write-swift and review-animations. Swift changes remain compatible with the project's Swift 6.1 package baseline; no toolchain or concurrency migration is included.

CleanMyMac informs approachable maintenance language and clear scope; Raycast informs immediate keyboard response. Local INDEX 102 (Fey) informs quiet, aligned data rows; 144 (Cursor) informs navigation without per-icon tiles and source/review context close to the task. These principles are adapted to a local cleanup utility. No proprietary artwork or full screen is copied. Mobbin's current screen search required a paid plan; these verified local and official references supply the comparison.

The coral-bin asset and original native resource provenance stay in docs/app-icon-prompt.txt and the existing resource metadata. PRODUCT.md remains the authority for actual capabilities, metric coverage and cleanup protections.

## Verification

Inspect a copied native bundle at normal and minimum window sizes. Check all eight pages, keyboard navigation, sidebar toggles, Overview review links, worktree filters/selection/cancel, Usage ranges, refresh and window reopen. Use --screenshots public fixtures with all live scans and cleanup disabled; public captions disclose example data. Native code is reviewed against the craft floor directly: the HTML/CSS detector has no verdict on SwiftUI.

The appearance refinement compares CleanMyMac (https://cleanmymac.com/fr) for approachable maintenance imagery with Raycast (https://www.raycast.com/) for restrained, readable operation and immediate keyboard behavior. Apple's Dark Mode guidance (https://developer.apple.com/design/human-interface-guidelines/dark-mode) informs independently composed appearances and a system default. We borrow those principles, not their screens or assets. Existing Fey/Cursor references remain the density and navigation baseline.
