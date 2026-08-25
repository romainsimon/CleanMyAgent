# Security policy

## Reporting a vulnerability

Please do not open a public issue for a vulnerability that could expose local conversations, source code, credentials, repository state, or enable unintended deletion.

Use GitHub's **Report a vulnerability** flow in the Security tab of this repository. Include the affected version or commit, reproduction steps, expected impact, and any suggested mitigation. Avoid attaching real private agent data; use a minimal synthetic fixture instead.

You should receive an initial acknowledgement within seven days. A fix timeline depends on severity and the affected adapter.

## Scope

Security-sensitive areas include filesystem target validation, worktree eligibility, subprocess invocation, local database parsing, process attribution, archive cleanup, and accidental content collection.
