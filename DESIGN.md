# CleanMyAgent Design Direction

## Mode

Operate. CleanMyAgent is a calm maintenance console for local AI tools: understand pressure quickly, inspect the evidence, and clean only after validation.

## Visual world

The product uses a refined macOS utility language rather than a terminal or admin-dashboard aesthetic. A deep midnight canvas and flat raised surfaces keep the evidence calm and legible. Color appears only where it explains health, source, or action.

The interface should feel reassuring under pressure. It can be friendly and dimensional without becoming playful, glossy everywhere, or visually detached from macOS.

## Reference synthesis

- CleanMyMac: borrow warmth, approachable system-health language, and the idea that maintenance can feel calm. Do not copy its artwork, characters, icons, or screen composition.
- DaisyDisk: borrow the immediate readability of used versus available storage and purposeful spectral color.
- Raycast and Apple utilities: borrow compact navigation, native window behavior, keyboard access, and information density.
- Existing CleanMyAgent product truth: preserve exact local evidence, agent identity, cleanup gates, and one-page scrolling for long tables.

## Structure

- The sidebar groups Monitor, Maintain, and System tasks. Selection is obvious but never louder than the current system state.
- Overview begins with one dominant system-health surface, followed by live throughput and evidence lists.
- Storage, worktrees, and usage retain one document-level scroll surface. Tables do not become nested scrolling islands.
- A menu-bar summary provides free space and current throughput without duplicating the app.

## Color and material

- Canvas: flat near-black indigo.
- Panels: flat deep blue-gray with one subtle edge; no decorative gradients, stacked borders, or shadows.
- Electric blue: navigation, healthy informational emphasis, and primary audit actions.
- Green: verified healthy or live state only.
- Amber and red: warning and critical states only.
- Violet and magenta: performance and agent identity, never cleanup safety.
- Agent colors identify source; they do not imply whether deletion is allowed.

## Typography

Use San Francisco through SwiftUI system styles. Page titles are 29 pt semibold with tight tracking. Measurements use rounded system numerals and monospaced digits. Supporting text stays compact and high-contrast enough to read without competing with evidence.

## Shape and spacing

Panels use 18–22 pt continuous corners. Sidebar items use 10–12 pt corners and compact 34 pt rows. The main content follows a 28 pt rhythm and remains readable from an 820 pt window to wide desktop layouts.

## Motion thesis

Motion explains change rather than decorating idle screens.

- Focal moment: an audit resolves into updated disk and agent measurements.
- Continuity: section changes use a short fade and 1% scale transition.
- Feedback: progress tracks ease to new values and the refresh control shows active work.
- Routine transitions run for 120–250 ms; metric resolution may take 350–500 ms.
- No bounce, perpetual glow, or ambient looping animation.
- Reduce Motion removes section transforms and metric interpolation while retaining status feedback.

## Safety language

Name the source, scope, last refresh time, and coverage. Do not call observed throughput provider speed. Cleaning surfaces must name the exact target, expected size, file count, reversibility, blocked states, and the point at which space is actually reclaimed. Never describe a destructive action as unconditionally safe.
