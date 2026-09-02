#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF="${ROOT_DIR}/bin/terraform"
VARFILE="${ROOT_DIR}/terraform.tfvars.ci"
OUT="${ROOT_DIR}/evidence/plan.txt"

cd "${ROOT_DIR}"

mkdir -p evidence

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS credentials not configured. Run 'aws configure' or export credentials." >&2
  echo "See evidence/VERIFY.md for honest submission guidance." >&2
  exit 1
fi

if [[ ! -f backend.hcl ]]; then
  echo "WARN: backend.hcl missing — running plan with -backend=false (bootstrap-only preview)." >&2
  (cd bootstrap && "${TF}" init -backend=false >/dev/null && "${TF}" plan -no-color) | tee "${OUT}.bootstrap"
  "${TF}" init -backend=false -reconfigure >/dev/null
  "${TF}" plan -var-file="${VARFILE}" -no-color | tee "${OUT}"
else
  "${TF}" init -backend-config=backend.hcl -reconfigure >/dev/null
  "${TF}" plan -var-file="${VARFILE}" -no-color | tee "${OUT}"
fi

echo "Plan captured to ${OUT}"
