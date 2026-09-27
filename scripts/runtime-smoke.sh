#!/bin/bash
set -euo pipefail
app="${1:-dist/CleanMyAgent.app}"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/cleanmyagent-smoke.XXXXXX")"
trap 'rm -rf "$smoke_root"' EXIT
mkdir -p "$smoke_root/home"
ditto "$app" "$smoke_root/CleanMyAgent.app"
if find "$smoke_root/CleanMyAgent.app" -type l | read -r; then
  echo "Unexpected symlink in standalone bundle" >&2
  exit 1
fi
cd "$smoke_root"
env -i HOME="$smoke_root/home" TMPDIR="$smoke_root" PATH=/usr/bin:/bin:/usr/sbin:/sbin "$smoke_root/CleanMyAgent.app/Contents/MacOS/CleanMyAgent" --smoke-test
