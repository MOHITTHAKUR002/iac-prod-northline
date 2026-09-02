# Verification Evidence

## Local (no AWS credentials)

These pass in CI/local without AWS access:

```bash
npm test
./bin/terraform fmt -check -recursive
(cd bootstrap && ../bin/terraform init -backend=false && ../bin/terraform validate)
./bin/terraform init -backend=false -reconfigure && ./bin/terraform validate
```

## Live plan (AWS credentials required)

To produce real `terraform plan` output for Caliber submission:

1. Configure AWS credentials (`aws sts get-caller-identity` succeeds)
2. Run bootstrap apply (see RUNBOOK.md)
3. `./scripts/write-backend-config.sh <bucket> <table>`
4. `./bin/terraform init -backend-config=backend.hcl`
5. `./bin/terraform plan -var-file=terraform.tfvars`

Paste the plan output into submission notes. If `apply` is blocked by org policy, note that honestly — a verified plan in a sandbox account is acceptable.

## Apply / destroy

Full lifecycle verification requires the same credentials plus permission to create VPC, RDS, ECS, ALB, and supporting IAM resources. Estimated monthly cost ~$132 (see README cost table).
