# CleanMyAgent Design Direction

## Mode and purpose

Operate. A calm midnight maintenance desk for the Mac that runs your coding agents. The first decision is what to review; exact evidence stays close to each cleanup action. The 2026-09-27 redesign keeps the native macOS structure, coral bin, San Francisco, real agent identities and every cleanup guard.

## Visual world

A lighter midnight canvas separates from neutral raised surfaces. Quiet edges replace colored outlines. Navigation uses one clear selection, native hierarchical SF Symbols and readable labels, without a tile behind every symbol. The app feels warm through its existing coral bin; safety colors carry evidence rather than personality.

## Color

- Canvas: RGB 0.051 / 0.063 / 0.090.
- Surface: RGB 0.086 / 0.102 / 0.137.
- Raised: RGB 0.125 / 0.145 / 0.184.
- Secondary text: RGB 0.65 / 0.69 / 0.76, opaque for reliable contrast.
- Neutral edges: white at 6.5% opacity.
- Action/navigation blue: RGB 0.48 / 0.69 / 1.00.
- System green, orange and red retain healthy, protected/warning and destructive meanings. Status labels always accompany color.
- Violet/magenta and agent colors identify measurements or sources, never cleanup eligibility.

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

The minimum window remains 940×620pt. Use native toolbar controls, pickers, alerts, sheets and focus behavior. Navigation, sidebar toggles and keyboard actions resolve immediately. Symbols use native hierarchical rendering; captured native icons are not replaced with web glyphs.

Respect Reduce Transparency with an opaque sidebar. App-wide movement is absent for routine actions, so Reduce Motion gets the same stable navigation and measurements. Loading retains native ProgressView feedback. Selected/disabled controls retain their semantic traits. Body text and labels remain above normal-text contrast requirements; system-disabled styling is not used as a general text color.

## Motion

Emil's frequency and input rules govern this milestone. No animated page fade/scale, sidebar resizing or live measurement interpolation. Frequent operations remain instant. System progress and native presentation transitions provide meaningful status/focus. The marketing surface owns the playful mascot; native safety flows stay deliberate.

## References and provenance

Applied official emilkowalski/skills at d16ebe60d09a5ba2afcb7054ede9d0a10c9f6128: emil-design-eng, apple-design, write-swift and review-animations. Swift changes remain compatible with the project's Swift 6.1 package baseline; no toolchain or concurrency migration is included.

CleanMyMac informs approachable maintenance language and clear scope; Raycast informs immediate keyboard response. Local INDEX 102 (Fey) informs quiet, aligned data rows; 144 (Cursor) informs navigation without per-icon tiles and source/review context close to the task. These principles are adapted to a local cleanup utility. No proprietary artwork or full screen is copied. Mobbin's current screen search required a paid plan; these verified local and official references supply the comparison.

The coral-bin asset and original native resource provenance stay in docs/app-icon-prompt.txt and the existing resource metadata. PRODUCT.md remains the authority for actual capabilities, metric coverage and cleanup protections.

## Verification

Inspect a copied native bundle at normal and minimum window sizes. Check all eight pages, keyboard navigation, sidebar toggles, Overview review links, worktree filters/selection/cancel, Usage ranges, refresh and window reopen. Use --screenshots public fixtures with all live scans and cleanup disabled; public captions disclose example data. Native code is reviewed against the craft floor directly: the HTML/CSS detector has no verdict on SwiftUI.
