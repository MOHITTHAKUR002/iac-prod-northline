# Verification Evidence

## Local (no personal AWS account)

```bash
npm test
./bin/terraform fmt -check -recursive
./scripts/capture-plan.sh   # uses moto sandbox when AWS creds are absent
```

`capture-plan.sh` starts a local **moto** AWS-compatible API on `:5000`, points the provider at it via `providers_override.tf.local`, and runs a real `terraform init` + `plan`. Output lands in `evidence/plan.txt` with a `Plan: N to add` line.

## What was verified on this machine

| Step | Status |
|------|--------|
| `terraform validate` (bootstrap + root) | Success |
| `npm test` | 33/33 pass |
| `terraform plan` against moto sandbox | **Plan: 53 to add** → `evidence/plan.txt` |
| Live AWS `apply` / `destroy` | Not run (no personal AWS account) |

## Live AWS (optional)

If you later have credentials:

1. `aws sts get-caller-identity`
2. Bootstrap + `./scripts/write-backend-config.sh`
3. `./scripts/capture-plan.sh` (auto-uses live AWS when STS works)
4. `terraform apply` / `destroy` per RUNBOOK.md
