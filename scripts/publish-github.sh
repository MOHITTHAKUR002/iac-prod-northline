#!/usr/bin/env bash
# Create GitHub repo, push iac-prod, and set mergeRequestUrl in SUBMIT_PREVIEW.json
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_NAME="${1:-iac-prod-northline}"
VISIBILITY="${2:-public}"   # public | private

cd "${ROOT_DIR}"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) not found. Install: brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub not logged in. Run this first (interactive — opens browser):"
  echo "  gh auth login"
  echo ""
  echo "Choose: GitHub.com → HTTPS → Login with browser (or paste token)"
  exit 1
fi

GITHUB_USER="$(gh api user -q .login)"
echo "GitHub user: ${GITHUB_USER}"

if [[ ! -d .git ]]; then
  git init -b main
  git add -A
  git commit -m "Northline production IaC for Caliber submission"
elif [[ -z "$(git status --porcelain)" ]]; then
  echo "Working tree clean."
else
  git add -A
  git commit -m "Caliber IaC attempt 2 — HTTPS ALB, validations, RUNBOOK RTO/RPO"
fi

# Create remote repo (skip if origin already points to github.com)
if git remote get-url origin >/dev/null 2>&1; then
  ORIGIN="$(git remote get-url origin)"
  if [[ "${ORIGIN}" == *github.com* ]]; then
    echo "origin already set: ${ORIGIN}"
    git push -u origin main
  else
    echo "origin is not GitHub (${ORIGIN}). Add GitHub remote manually or remove origin first."
    exit 1
  fi
else
  echo "Creating github.com/${GITHUB_USER}/${REPO_NAME} (${VISIBILITY})..."
  gh repo create "${REPO_NAME}" \
    --"${VISIBILITY}" \
    --source=. \
    --remote=origin \
    --push \
    --description "Northline production Terraform — Caliber IaC module"
fi

REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo ""
echo "Repository URL: ${REPO_URL}"

# Update SUBMIT_PREVIEW.json if it exists
PREVIEW="${ROOT_DIR}/SUBMIT_PREVIEW.json"
if [[ -f "${PREVIEW}" ]] && command -v node >/dev/null 2>&1; then
  node -e "
const fs = require('fs');
const p = '${PREVIEW}';
const url = '${REPO_URL}';
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
j.mergeRequestUrl = url;
j.answer = j.answer.replace('<PASTE_GITHUB_URL_HERE>', url);
j.answer = j.answer.replace(/mergeRequestUrl:.*$/m, 'mergeRequestUrl: ' + url);
if (!j.answer.includes(url)) {
  j.answer = j.answer.replace(
    '## GitHub repository\\n',
    '## GitHub repository\\n' + url + '\\n'
  );
}
fs.writeFileSync(p, JSON.stringify(j, null, 2));
console.log('Updated SUBMIT_PREVIEW.json mergeRequestUrl →', url);
"
fi

echo ""
echo "Done. Use this in Caliber submit:"
echo "  mergeRequestUrl: ${REPO_URL}"
