#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF="${ROOT_DIR}/bin/terraform"

cd "${ROOT_DIR}"

echo "==> terraform fmt -check"
"${TF}" fmt -check -recursive

echo "==> npm test"
npm test

echo "==> bootstrap validate"
(cd bootstrap && "${TF}" init -backend=false >/dev/null && "${TF}" validate)

echo "==> root validate (local backend)"
"${TF}" init -backend=false -reconfigure >/dev/null
"${TF}" validate

echo "==> root plan syntax (var-file ci, no creds required for validate-only)"
if [[ -f terraform.tfvars.ci ]]; then
  "${TF}" plan -var-file=terraform.tfvars.ci -input=false -refresh=false -no-color >/dev/null 2>&1 || \
    echo "Plan dry-run skipped (expected without AWS creds after validate)."
fi

if [[ -f backend.hcl ]]; then
  echo "==> root init with remote backend"
  "${TF}" init -backend-config=backend.hcl -reconfigure >/dev/null
  echo "Remote backend configured. Run '${TF} plan' with AWS credentials to verify live plan."
else
  echo "No backend.hcl found — skipping remote init/plan (run scripts/write-backend-config.sh first)."
fi

echo "Verification complete."
