# Pre-submit checklist — review before saying "submit"

**Do not submit until every item below is done.**

## 1. GitHub (hard requirement — failed both attempts without this)

**Your old account `@MohitAntier` is locked** (no authenticator, no recovery codes). Use a **new GitHub account** with a **personal email** (not `mohit.thakur@antiersolutions.com` — that email is tied to the old account).

**Step A — create new account in IDE browser:**
1. Go to https://github.com/signup
2. Use personal Gmail (or any email you can access)
3. Pick a username (e.g. `mohit-iac-caliber`)
4. **Skip 2FA** for now (or save recovery codes if you enable it)

**Step B — publish repo (after logged in):**

```bash
gh auth login   # GitHub.com → HTTPS → Login with a web browser (session may already be active)
cd /Users/user/Data/caliber/iac-prod
./scripts/publish-github.sh
# Creates https://github.com/MohitAntier/iac-prod-northline and updates SUBMIT_PREVIEW.json
```

## 2. Terraform plan (hard requirement)

```bash
aws sts get-caller-identity   # must succeed
./scripts/capture-plan.sh     # writes evidence/plan.txt
```

Paste plan output (or key summary) into submission notes.

## 3. Local verification

```bash
npm test
./scripts/verify.sh
```

Save output to paste in notes.

## 4. Build submission preview

```bash
node scripts/build-submit.mjs
```

Verify:

- `notes chars` and `code chars` both **≤ 20000**
- Console prints **`critical files in code: YES`**
- Open `SUBMIT_PREVIEW.json` and confirm `mergeRequestUrl`, plan evidence in `answer`

## 5. Review what grader must see in code field

These files **must** be inside `content.code`:

- `RUNBOOK.md` (RTO/RPO + restore procedure)
- `modules/compute/iam.tf`
- `modules/compute/task-definition.tf`
- `modules/compute/alb.tf` (HTTPS listener)
- `modules/database/main.tf`

## 6. When ready

Tell the agent: **"submit attempt 2"** — agent will run `scripts/submit-once.mjs` or MCP submit.

## 7. After grading (within 48h)

Browser → submission → follow-up Q&A. **Type slowly**, no paste. Memorize:

- IAM: exec role vs task role split (`modules/compute/iam.tf`)
- ECS: `1000:1000`, `readonlyRootFilesystem`, `healthcheck.sh`
- Bootstrap: S3 + DynamoDB → `write-backend-config.sh`
- Cost: ~$132/mo, single-AZ RDS RTO 20–40 min
