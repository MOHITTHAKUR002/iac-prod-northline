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
# build, tag, push to ECR — see README
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

## Cost cap ($150/mo) — trade-offs & operational consequences

Budget **~$132/mo** (README table). Chosen trade-offs:

| Choice | Consequence |
|--------|-------------|
| **Single-AZ RDS** | **RPO ~5 minutes** data loss on AZ failure. **RTO 20–40 minutes**: alarm → restore from 7-day snapshot → ECS redeploy. *Estimate — not restore-drill verified.* |
| **Single NAT** | NAT-AZ loss blocks general internet egress from other AZ; ECR/Secrets/Logs still via VPC endpoints. |
| **Fargate Spot + on-demand base=1** | ≥1 task always on **FARGATE** (not Spot-only). Remaining tasks may use Spot. Spot reclaim → temporary capacity drop until ECS replaces Spot tasks (**~1–3 min** at reduced capacity). |

### Restore procedure (RDS AZ failure)

1. Confirm RDS alarm / failed `/ready` checks.
2. RDS console → **Restore to point in time** (or latest snapshot).
3. Update endpoint in task env if identifier changed; `terraform apply` if wiring changed.
4. Force ECS new deployment; smoke `https://$ALB/health`.
5. **Wall-clock RTO estimate: 20–40 minutes** (not drill-verified).

Sandbox defaults: `skip_final_snapshot=true`, `deletion_protection=false` — override for real prod.
