# Contributing to CleanMyAgent

Thanks for helping make local coding-agent maintenance safer and easier to understand.

## Before opening a change

- Search the existing issues and keep one pull request focused on one logical change.
- For a new agent adapter, document the local source, supported versions, provenance of every metric, and how duplicate counting is avoided.
- For a new cleanup action, start with an audit-only implementation and define every protected state before enabling mutation.
- Never add fixtures containing real prompts, responses, source code, access tokens, usernames, or private repository paths.

## Development

```bash
swift test
swift run CleanMyAgent
```

To build the local `.app` bundle:

```bash
./scripts/build-app.sh
```

## Pull-request checklist

- Tests cover new parsing, attribution, or cleanup rules.
- Unknown and failed states default to protection.
- User-facing metrics name their source and coverage honestly.
- Cleanup remains previewed, explicit, narrowly scoped, and revalidated at execution time.
- The app still builds on macOS 14 or later with Swift 6.1.
- UI changes support keyboard use, adequate contrast, and Reduce Motion where relevant.

By contributing, you agree that your contributions will be licensed under the MIT License.
