# RUNBOOK — Northline Production IaC

Clone → bootstrap → configure → init → plan → apply → smoke → destroy.

**Repo:** https://github.com/MOHITTHAKUR002/iac-prod-northline

## Prerequisites

AWS CLI + credentials, Node.js ≥ 18, Docker, ACM cert in deployment region, `bin/terraform` (v1.9.8).

## 1. Clone & test

```bash
git clone https://github.com/MOHITTHAKUR002/iac-prod-northline iac-prod && cd iac-prod
npm test
```

## 2. Bootstrap remote state

```bash
cd bootstrap && ../bin/terraform init && ../bin/terraform apply -var="project_prefix=northline" && cd ..
BUCKET=$(cd bootstrap && ../bin/terraform output -raw state_bucket_name)
TABLE=$(cd bootstrap && ../bin/terraform output -raw dynamodb_table_name)
./scripts/write-backend-config.sh "$BUCKET" "$TABLE"
cp terraform.tfvars.example terraform.tfvars   # set acm_certificate_arn; container_port defaults to 8080
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
# build with same PORT as var.container_port (default 8080)
docker build --build-arg PORT=8080 -t northline-api api/
ALB=$(./bin/terraform output -raw alb_dns_name)
curl -sf "https://${ALB}/health"
curl -sI "http://${ALB}/health" | grep -i location   # 301 → https
```

## 5. Verify & destroy

```bash
./scripts/verify.sh
./bin/terraform destroy -var-file=terraform.tfvars
(cd bootstrap && ../bin/terraform destroy)
```

---

## Cost cap ($150/mo) — itemized (~$132)

| Line item | Est. $/mo |
|-----------|-----------|
| 1× NAT Gateway | ~32 |
| ALB | ~22 |
| Fargate (1 on-demand base + Spot remainder, autoscaling max=4) | ~20–28 |
| RDS db.t4g.micro single-AZ + 20 GiB | ~15 |
| VPC interface endpoints (ECR×2, Secrets, Logs) | ~28 |
| CloudWatch Logs / alarms | ~5 |
| S3 + DynamoDB state | ~2 |
| Buffer | ~10 |
| **Total** | **~$132** |

| Choice | Consequence |
|--------|-------------|
| **Single-AZ RDS** | **RPO ~5 minutes**. **RTO estimate 20–40 minutes** if restore is rehearsed; live restores often run longer (see below). |
| **Single NAT** | Cross-AZ egress SPOF for non-AWS traffic; ECR/Secrets/Logs stay on VPC endpoints. `failure_domains.single_nat_risk` surfaces multi-AZ private subnets sharing one NAT. |
| **Fargate Spot + on-demand base=1** | ≥1 task always on **FARGATE**. Beyond base, weight prefers Spot (~3:1). Spot reclaim drops capacity until ECS replaces tasks (**~1–3 min** at reduced capacity). Autoscaling `ecs_max_capacity` (default 4) caps spend. |

### Spot interruption handling

ECS replaces interrupted Spot tasks automatically. Keep `deployment_minimum_healthy_percent=100` so replacements start before draining completes. Do not raise `ecs_max_capacity` above ~4 without revisiting the $150 table (more Spot tasks also amplify reclaim storms).

### Restore procedure (RDS AZ failure)

1. Confirm RDS alarm / failed `/ready` checks.
2. Run `./scripts/restore-rds.sh northline-prod-postgres` (or console restore-from-snapshot).
3. Rewire `DB_HOST` via terraform/ECS task env to the new endpoint; `terraform apply` if identifier changed.
4. Force ECS new deployment; smoke `https://$ALB/health` and `/ready`.
5. **Why wall-clock can exceed 20–40m:** new endpoint + Secrets Manager password, no in-repo automated cutover, snapshot restore duration, single-AZ rebuild, no cross-region replica.

Sandbox defaults: `skip_final_snapshot=true`, `deletion_protection=false` — override for real prod.
