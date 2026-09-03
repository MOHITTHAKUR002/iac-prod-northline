#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; TF="$ROOT/bin/terraform"; cd "$ROOT"
"$TF" fmt -check -recursive
npm test
(cd bootstrap && "$TF" init -backend=false >/dev/null && "$TF" validate)
"$TF" init -backend=false -reconfigure >/dev/null && "$TF" validate
[[ -f backend.hcl ]] && "$TF" init -backend-config=backend.hcl -reconfigure >/dev/null || true
echo "Verification complete."
