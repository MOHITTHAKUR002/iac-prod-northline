#!/usr/bin/env bash
# Capture a real `terraform plan` for Caliber evidence.
# Prefers live AWS; falls back to local moto sandbox (no personal AWS account).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF="${ROOT_DIR}/bin/terraform"
VARFILE="${ROOT_DIR}/terraform.tfvars.ci"
OUT="${ROOT_DIR}/evidence/plan.txt"
MOTO_PID=""
OVERRIDE="${ROOT_DIR}/providers_override.tf"
OVERRIDE_SRC="${ROOT_DIR}/providers_override.tf.local"
VERSIONS="${ROOT_DIR}/versions.tf"
VERSIONS_BAK="${ROOT_DIR}/versions.tf.planbak"
BOOT_OVERRIDE="${ROOT_DIR}/bootstrap/providers_override.tf"

cleanup() {
  if [[ -n "${MOTO_PID}" ]] && kill -0 "${MOTO_PID}" 2>/dev/null; then
    kill "${MOTO_PID}" 2>/dev/null || true
  fi
  rm -f "${OVERRIDE}" "${BOOT_OVERRIDE}"
  if [[ -f "${VERSIONS_BAK}" ]]; then
    mv "${VERSIONS_BAK}" "${VERSIONS}"
  fi
}
trap cleanup EXIT

cd "${ROOT_DIR}"
mkdir -p evidence

use_live_aws=false
if aws sts get-caller-identity >/dev/null 2>&1; then
  use_live_aws=true
fi

if [[ "${use_live_aws}" == "true" ]]; then
  echo "==> Using live AWS credentials"
  if [[ -f backend.hcl ]]; then
    "${TF}" init -backend-config=backend.hcl -reconfigure >/dev/null
    "${TF}" plan -var-file="${VARFILE}" -no-color -input=false | tee "${OUT}"
  else
    echo "WARN: backend.hcl missing — local backend for plan only." >&2
    cp "${VERSIONS}" "${VERSIONS_BAK}"
    python3 - <<'PY'
from pathlib import Path
p = Path("versions.tf")
text = p.read_text()
text = text.replace('backend "s3" {}', 'backend "local" {\n    path = "evidence/terraform.tfstate.plan"\n  }')
p.write_text(text)
PY
    "${TF}" init -reconfigure -input=false >/dev/null
    "${TF}" plan -var-file="${VARFILE}" -no-color -input=false | tee "${OUT}"
  fi
else
  echo "==> No live AWS — starting moto sandbox on :5000"
  if ! curl -sf http://127.0.0.1:5000/ >/dev/null 2>&1; then
    if [[ ! -x .venv-moto/bin/moto_server ]]; then
      echo "ERROR: moto not installed. Run: python3 -m venv .venv-moto && .venv-moto/bin/pip install 'moto[server]' boto3" >&2
      exit 1
    fi
    .venv-moto/bin/moto_server -p 5000 -H 127.0.0.1 >/tmp/moto-server.log 2>&1 &
    MOTO_PID=$!
    for _ in $(seq 1 30); do
      curl -sf http://127.0.0.1:5000/ >/dev/null 2>&1 && break
      sleep 0.2
    done
  fi

  export AWS_ACCESS_KEY_ID=test
  export AWS_SECRET_ACCESS_KEY=test
  export AWS_DEFAULT_REGION=us-east-1
  export AWS_EC2_METADATA_DISABLED=true

  cp "${OVERRIDE_SRC}" "${OVERRIDE}"
  cp "${OVERRIDE_SRC}" "${BOOT_OVERRIDE}"

  # Partial S3 backend cannot init without bucket — use local backend for sandbox plan.
  cp "${VERSIONS}" "${VERSIONS_BAK}"
  python3 - <<'PY'
from pathlib import Path
p = Path("versions.tf")
text = p.read_text()
text = text.replace('backend "s3" {}', 'backend "local" {\n    path = "evidence/terraform.tfstate.plan"\n  }')
p.write_text(text)
PY

  export TF_DATA_DIR="${ROOT_DIR}/.terraform-moto"
  "${TF}" init -reconfigure -input=false >/dev/null
  {
    echo "# Terraform plan — local AWS-compatible sandbox (moto)"
    echo "# Demonstrates init → plan against mock AWS APIs (account 123456789012)."
    echo "# Live AWS apply/destroy not run — no personal AWS account on this machine."
    echo "# Date: $(date -u +%Y-%m-%dT%H:%MZ)"
    echo
    "${TF}" plan -var-file="${VARFILE}" -no-color -input=false
  } | tee "${OUT}"
fi

if ! grep -qE '^Plan:[[:space:]]*[0-9]+' "${OUT}"; then
  echo "ERROR: evidence/plan.txt missing Plan: N to add line" >&2
  exit 1
fi

echo "Plan captured to ${OUT}"
