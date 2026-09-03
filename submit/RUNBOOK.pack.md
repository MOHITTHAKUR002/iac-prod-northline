# RUNBOOK — Northline IaC

## Operational consequence (single-AZ RDS)
**RPO ≈ 5 minutes** of data loss on AZ failure. **RTO ≈ 25–40 minutes** of downtime until restore from the most recent automated snapshot (`backup_retention_period=7`), Secrets Manager password on the new instance, terraform/ECS `DB_HOST` rewire, and force-new-deployment. Helper: `./scripts/restore-rds.sh`. Defaults: `skip_final_snapshot=false`, `deletion_protection=true`.

## Operational consequence (single NAT)
NAT AZ failure blocks general internet egress from other private AZs (~15–30m to add a second NAT). ECR/Secrets/Logs stay on VPC endpoints. See `failure_domains.single_nat_risk`.

```bash
npm test && ./scripts/verify.sh
# bootstrap → write-backend-config.sh → init -backend-config=backend.hcl
# versions.tf contains: backend "s3" {}
./bin/terraform plan -var-file=terraform.tfvars | tee evidence/plan.txt
```

~$132/mo. `var.fargate_base`/`weight`/`spot_weight`. `var.container_port` → SG+TG+task. RDS via task secrets DB_USER/DB_PASSWORD.
