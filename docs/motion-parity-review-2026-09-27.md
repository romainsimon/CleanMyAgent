# App and website motion parity review

This milestone applies the user's request for more delightful transitions and charts to the native Mac app and the website simulation. Impeccable Operate context, emil-design-eng and a separate review-animations pass govern it. The native app is the visual source of truth; no cleanup or scanning service changes.

| Before | After | Why |
| --- | --- | --- |
| Instant pointer navigation; a different preview sidebar | Same eight destinations, 212-point sidebar and 180ms page/selection continuity | Keep location clear without delaying interaction |
| Abrupt chart entry | Baseline reveal within 260ms; native numeric range transition | Make the data change easier to follow |
| Preview cache/reasoning added to input/output again | Total = input + output; five non-overlapping categories | Match the native metric definition without double counting |
| Preview shortened Performance view and missing agent rows | Native idle meter and eight-agent evidence table | Missing measurements remain missing; identical visual hierarchy |
| Retargeting after cancellation snapped the preview selection | Capture the current visual rectangle before cancellation | Rapid navigation continues from the visible position |
| Keyboard input policy updated after tab handlers | Capture-phase policy before handlers; immediate keyboard actions | Avoid a first-frame keyboard animation |
| Symmetric button feedback | 120ms press, 80ms release | Acknowledge the deliberate action, then settle quickly |
| Currency wraps in the native minimum window | Adaptive summary grid and one-line values | Preserve readable measurements at 940×620 content size |
| 10px preview metric qualifications | 11px minimum | Keep functional evidence readable |
| A CSS contour crops a real screenshot window | Preserve the capture's original alpha contour | Native toolbar and corners stay intact |

## Motion verdict

Approve at source level. RootView.swift:17 controls input/accessibility policy; Theme/AgentSpaceMotion.swift:4 defines the 180/260/120/80ms budgets and strong (.23,1,.32,1) ease-out; its chart modifier cancels pending tasks and settles on motion-policy changes. UsageView.swift:70 adapts the summary and chart selection remains native. Website preview.js:41 gates pointer motion, :52 retargets the selection from its current appearance, :79 handles keyboard policy before navigation, and :168 derives range data from the shared public equations. CSS press feedback and SwiftUI state transitions are interruptible; no live-width tween, loop or animation dependency is added.

Bar scale starts at .08 from the plotted baseline: this explains measured bar magnitude, rather than making a control appear from scale zero. Only the plot is transformed; native axes and domains remain stable. The website rebuilds its fixture plot on range choice and cancels stale reveals; it never retains an outgoing interactive panel. Native SwiftUI transitions retarget through normal state transactions. Motion never gates safety evaluation or a confirmation action. Keyboard and reduced motion disable custom animation completely, following the stricter project input/accessibility rule. Hover styling is gated to fine pointers with hover support.

Reference: [Emil's frequency guidance](https://emilkowal.ski/ui/you-dont-need-animations), [Apple SwiftUI animation timing](https://developer.apple.com/documentation/swiftui/controlling-the-timing-and-movements-of-your-animations), and the actual native screens. Local Fey 102 informs aligned evidence rows; Cursor 144 informs quiet grouped navigation. No proprietary screen or artwork is copied.

## Verification and limits

First consolidated inspection: native public fixtures in a copied universal bundle outside the checkout; all eight pages, 7/30/90-day ranges, safe selection/confirmation cancellation, sidebar hide/show, normal and minimum content sizes. The web preview was inspected at 1440px, 390px and 320px: all eight destinations, one visible panel, range totals, cancellation/focus return, arrow navigation and no page overflow. The batch corrected the differences above. Final candidate artifact checks and one final confirmation round are recorded in the PR validation; this document does not assert a public release.

Swift checks cover the input/reduced-motion policy and fixture parity, alongside existing conservative cleanup and parser tests. Website checks cover static assets and native fixture totals/composition. Production runtime smoke checks the standalone final bundle/image without mounting source.

The Impeccable detector ran once over changed web UI targets. Its 10px qualification findings were fixed. The report-table padding warning is a wrapper false positive: cells have 12px×14px inset. Coral headings exceed large-text contrast; the two invisible images are the inactive mascot sprites already reviewed in the earlier milestone. Cream, native color/radius advisories and aphoristic copy preserve the approved brand and product context. Native SwiftUI was reviewed directly because the HTML/CSS detector does not validate it.

Public screenshots use --screenshots fixtures, with no Demo data label in the image. Captions disclose example data. No real user cleanup was exercised. The download stays on v0.2.1 until a separate native release is published; these source/build results are not notarization or production launch evidence.
