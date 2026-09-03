#!/usr/bin/env bash
set -euo pipefail
BUCKET="${1:?}"; TABLE="${2:?}"; REGION="${3:-us-east-1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
printf 'bucket="%s"\nkey="prod/terraform.tfstate"\nregion="%s"\ndynamodb_table="%s"\nencrypt=true\n' "$BUCKET" "$REGION" "$TABLE" >"$ROOT/backend.hcl"
echo "Wrote backend.hcl — run bin/terraform init -backend-config=backend.hcl"
