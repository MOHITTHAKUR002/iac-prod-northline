# RUNBOOK — Northline Production IaC

**Repo:** https://github.com/MOHITTHAKUR002/iac-prod-northline

## Operational consequences (cost trade-offs — required reading)

### Single-AZ RDS (`multi_az = false`, `db.t4g.micro`, `backup_retention_period = 7`)
- **RPO ≈ 5 minutes** of committed data on AZ failure (PITR / automated backups; not zero because in-flight commits at failure are lost).
- **RTO ≈ 25–40 minutes** of API downtime until restore from the most recent automated snapshot (or PITR), Secrets Manager password on the new instance, terraform/ECS rewire of `DB_HOST`, and force-new-deployment. Wall-clock often exceeds 40 minutes if restore is unrehearsed.
- Defaults: `skip_final_snapshot = false`, `deletion_protection = true` so the backup story stays honest. Sandbox teardown must override both in tfvars.

### Single NAT Gateway (`modules/networking/nat.tf` → `aws_subnet.public[0]`)
- **Operational consequence:** if the NAT AZ fails, private-subnet tasks in the other AZ lose general internet egress for **the duration of the AZ outage or until a second NAT is provisioned (~15–30 minutes of terraform apply)**. AWS API traffic (ECR, Secrets Manager, Logs) continues via VPC interface endpoints; S3 uses the gateway endpoint. Flagged by `failure_domains.single_nat_risk`.

### Fargate Spot (`fargate_base` default 1, `fargate_spot_weight` default 3)
- Spot reclaim → **≈1–3 minutes** at reduced capacity while ECS replaces tasks; ≥1 on-demand task remains.

---

Clone → bootstrap → configure → init → plan → apply → smoke → destroy.

## Prerequisites

AWS CLI + credentials, Node.js ≥ 18, Docker, ACM cert in deployment region, `bin/terraform` (v1.9.8).

## 1. Clone & test

```bash
git clone https://github.com/MOHITTHAKUR002/iac-prod-northline iac-prod && cd iac-prod
npm test
```

## 2. Bootstrap remote state

Root uses `backend "s3" {}` in `versions.tf` (partial config). Bootstrap creates the bucket + DynamoDB lock table:

```bash
cd bootstrap && ../bin/terraform init && ../bin/terraform apply -var="project_prefix=northline" && cd ..
BUCKET=$(cd bootstrap && ../bin/terraform output -raw state_bucket_name)
TABLE=$(cd bootstrap && ../bin/terraform output -raw dynamodb_table_name)
./scripts/write-backend-config.sh "$BUCKET" "$TABLE"
cp terraform.tfvars.example terraform.tfvars   # set acm_certificate_arn
```

## 3. Init → plan → apply

```bash
./bin/terraform init -backend-config=backend.hcl
./bin/terraform plan -var-file=terraform.tfvars -out=tfplan | tee evidence/plan.txt
./bin/terraform apply tfplan
./bin/terraform output failure_domains
```

## 4. Container push & smoke (HTTPS)

```bash
ECR=$(./bin/terraform output -raw ecr_repository_url)
docker build --build-arg PORT=8080 -t northline-api api/
ALB=$(./bin/terraform output -raw alb_dns_name)
curl -sf "https://${ALB}/health"
```

## 5. Verify & destroy

```bash
./scripts/verify.sh
# Sandbox teardown requires: skip_final_snapshot=true deletion_protection=false
./bin/terraform destroy -var-file=terraform.tfvars
(cd bootstrap && ../bin/terraform destroy)
```

## Cost cap ($150/mo) — itemized (~$132)

| Line item | Est. $/mo |
|-----------|-----------|
| 1× NAT Gateway | ~32 |
| ALB | ~22 |
| Fargate (1 on-demand base + Spot remainder, max=4) | ~20–28 |
| RDS db.t4g.micro single-AZ + 20 GiB | ~15 |
| VPC interface endpoints | ~28 |
| CloudWatch / S3 state / buffer | ~17 |
| **Total** | **~$132** |

### Restore procedure (RDS AZ failure)

1. Confirm RDS alarm / failed `/ready`.
2. `./scripts/restore-rds.sh northline-prod-postgres`
3. Update `DB_HOST` via terraform apply (task definition env) or CNAME; force ECS new deployment.
4. Smoke `https://$ALB/health` and `/ready`.
5. Expect **25–40+ minutes** RTO as quantified above.
