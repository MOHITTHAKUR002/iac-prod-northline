# RUNBOOK — Northline Production IaC

Operational guide: clone → bootstrap → configure → init → plan → apply → smoke → destroy.

## Prerequisites

- AWS CLI configured with credentials for a sandbox account
- Node.js ≥ 18
- This repo includes `bin/terraform` (v1.9.8)

## 1. Clone

```bash
git clone <your-repo-url> iac-prod
cd iac-prod
npm test   # static + API tests, no AWS required
```

## 2. Bootstrap remote state

Creates S3 bucket (versioned, encrypted) and DynamoDB lock table.

```bash
cd bootstrap
../bin/terraform init
../bin/terraform apply -var="project_prefix=northline"
cd ..

# Capture outputs
BUCKET=$(cd bootstrap && ../bin/terraform output -raw state_bucket_name)
TABLE=$(cd bootstrap && ../bin/terraform output -raw dynamodb_table_name)
```

## 3. Configure backend

```bash
chmod +x scripts/*.sh
./scripts/write-backend-config.sh "$BUCKET" "$TABLE"
```

This writes `backend.hcl` (gitignored). Copy `terraform.tfvars.example` → `terraform.tfvars` and adjust if needed.

## 4. Init

```bash
./bin/terraform init -backend-config=backend.hcl
```

## 5. Plan

```bash
./bin/terraform plan -var-file=terraform.tfvars -out=tfplan
```

Review the plan. Expected resources: VPC, NAT, endpoints, RDS, ECS, ALB, ECR, alarms.

Paste plan output into submission notes for Caliber grading.

## 6. Apply

```bash
./bin/terraform apply tfplan
```

Capture outputs:

```bash
./bin/terraform output alb_dns_name
./bin/terraform output failure_domains
```

## 7. Build & push container

```bash
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR=$(./bin/terraform output -raw ecr_repository_url)

aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

docker build -t northline-api ./api
docker tag northline-api:latest "$ECR:latest"
docker push "$ECR:latest"

aws ecs update-service --cluster "$(./bin/terraform output -raw ecs_cluster_name)" \
  --service "$(./bin/terraform output -raw ecs_service_name)" \
  --force-new-deployment
```

## 8. Smoke test

```bash
ALB=$(./bin/terraform output -raw alb_dns_name)
curl -sf "http://${ALB}/health" | jq .
curl -sf "http://${ALB}/ready" | jq .
```

Expected: `{"status":"ok",...}` and `{"status":"ready",...}`.

## 9. Automated verification

```bash
./scripts/verify.sh
```

Runs `terraform fmt -check`, `npm test`, and `terraform validate` for bootstrap and root.

## 10. Destroy (teardown)

```bash
./bin/terraform destroy -var-file=terraform.tfvars

cd bootstrap
../bin/terraform destroy
```

Empty the state bucket first if destroy fails on non-empty bucket.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| ECS tasks not starting | Check ECR image pushed; verify VPC endpoints and NAT |
| RDS connection errors | Confirm ECS SG allowed on RDS SG; credentials in Secrets Manager |
| Backend init fails | Re-run `write-backend-config.sh` with correct bucket/table |
| `failure_domains.single_nat_risk = true` | Expected with single NAT — document in submission |

## Submission checklist (Caliber)

- [ ] GitHub repo URL in submission
- [ ] Real `terraform plan` output pasted
- [ ] Full file tree via `filePaths` or complete repo
- [ ] `npm test` + `./scripts/verify.sh` output
- [ ] `promptLogs` with 3–6 expert prompts
- [ ] Reference this RUNBOOK in notes
