<p align="center">
  <img src="Sources/AgentSpace/Resources/AppIcon/cleanmyagent-app-icon.png" width="144" alt="CleanMyAgent app icon">
</p>

<h1 align="center">CleanMyAgent</h1>

<p align="center">
  A local-first macOS control center for the storage, worktrees, memory, usage, and observed speed of coding agents.
</p>

<p align="center">
  <a href="https://github.com/romainsimon/CleanMyAgent/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/romainsimon/CleanMyAgent/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111827?logo=apple">
  <img alt="Swift 6.1" src="https://img.shields.io/badge/Swift-6.1-F05138?logo=swift&logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-22c55e"></a>
</p>

CleanMyAgent explains what your local coding agents are using before it offers to clean anything. It combines disk attribution, process memory, Git worktree safety checks, local usage charts, and an observed token speedometer in one native SwiftUI app.

> [!IMPORTANT]
> CleanMyAgent is an early open-source macOS project. Review every cleanup preview. Storage pressure is never treated as permission to delete data.

## What it does

- Measures free disk space and attributes known local storage categories to supported coding agents.
- Monitors attributable process count and resident memory.
- Audits linked Git worktrees and explains exactly why each one is removable or protected.
- Removes a worktree only after rechecking that it is inactive, unlocked, clean, tracked, pushed, and integrated.
- Charts local token activity by day, agent, model, and token category where structured metadata is available.
- Shows locally observed throughput, TTFT, response time, and coverage without presenting them as provider-side benchmarks.
- Moves archived Codex sessions to the macOS Trash only after confirmation and only while Codex is closed.
- Runs locally, without indexing prompt, response, source-code, or tool-output content.

## Supported tools

| Tool | Storage | Memory | Usage | Speed | Worktrees |
| --- | :---: | :---: | :---: | :---: | :---: |
| Codex | ✓ | ✓ | ✓ | ✓ | ✓ |
| Claude Code | ✓ | ✓ | ✓ | Observed | ✓ |
| Grok Build | ✓ | ✓ | ✓ | Observed | ✓ |
| Cursor | ✓ | ✓ | Partial | — | ✓ |
| Hermes Agent | ✓ | ✓ | ✓ | Observed | ✓ |
| OpenCode | ✓ | ✓ | ✓ | Observed | ✓ |
| Ori | ✓ | ✓ | Launcher history | — | ✓ |
| Kilo Code | ✓ | ✓ | Partial | — | ✓ |

“Observed” means derived from local structured events. Coverage differs by agent and version. Ori launcher activity is not counted a second time when the underlying agent already owns the usage.

## Cleanup safety model

CleanMyAgent defaults to protection. A worktree remains blocked if any of these conditions is true or cannot be established:

- it is the active or a locked worktree;
- it has modified, staged, or untracked files;
- it contains commits that have not been pushed;
- its branch is not integrated into the default branch;
- its pull request is open, closed without merging, or unknown;
- Git or GitHub verification fails.

Eligible worktrees are removed with `git worktree remove`, never by deleting their directories directly. The branch and remote pull request are left intact. All checks run again immediately before removal.

Archived Codex sessions use the macOS Trash and remain recoverable until the Trash is emptied. Active Codex sessions are never selected by that action.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or a Swift 6.1 toolchain
- Git
- Optional: an authenticated [GitHub CLI](https://cli.github.com/) for pull-request verification

## Run from source

```bash
git clone https://github.com/romainsimon/CleanMyAgent.git
cd CleanMyAgent
swift run CleanMyAgent
```

Run the test suite:

```bash
swift test
```

Build a local application bundle:

```bash
./scripts/build-app.sh
open "dist/CleanMyAgent.app"
```

The generated app is ad-hoc signed for local development. It is not notarized or distributed as a release yet.

## Privacy

Scans happen on your Mac. CleanMyAgent reads numeric metadata, opaque identifiers, filesystem sizes, process information, and Git state. It intentionally ignores conversation content, generated code, prompts, responses, and tool output.

There is no application telemetry. Network access is limited to GitHub pull-request verification performed through your existing local `gh` authentication when that evidence is needed.

## Project structure

```text
Sources/AgentSpace/
├── Models/       Data contracts and safety states
├── Services/     Agent, disk, process, usage, and Git scanners
├── Store/        Application state and refresh orchestration
├── Theme/        Native visual system and shared controls
└── Views/        SwiftUI screens
```

The Swift package and executable are named `CleanMyAgent`. The internal module remains `AgentSpace` for now to preserve the project history and keep this first public release focused.

## Contributing

Bug reports and focused pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), and report security issues through the private process in [SECURITY.md](SECURITY.md).

## License

CleanMyAgent source code is available under the [MIT License](LICENSE). Third-party product names and logos remain the property of their respective owners; see [NOTICE.md](NOTICE.md).
