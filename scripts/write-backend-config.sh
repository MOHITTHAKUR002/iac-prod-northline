#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF="${ROOT_DIR}/bin/terraform"

BUCKET="${1:-}"
TABLE="${2:-}"
REGION="${AWS_REGION:-us-east-1}"
KEY="${TF_STATE_KEY:-prod/terraform.tfstate}"

if [[ -z "${BUCKET}" || -z "${TABLE}" ]]; then
  echo "Usage: $0 <state_bucket_name> <dynamodb_lock_table>" >&2
  exit 1
fi

cat > "${ROOT_DIR}/backend.hcl" <<EOF
bucket         = "${BUCKET}"
key            = "${KEY}"
region         = "${REGION}"
dynamodb_table = "${TABLE}"
encrypt        = true
EOF

echo "Wrote ${ROOT_DIR}/backend.hcl"
