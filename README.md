# Northline Production Infrastructure

Terraform project that provisions a cost-conscious, production-style AWS environment for a containerized Node.js API backed by PostgreSQL.

## Architecture

| Layer | Module | Key resources |
|-------|--------|---------------|
| Network | `modules/networking` | VPC, public/private subnets, single NAT, interface VPC endpoints (ECR, Secrets Manager, Logs), S3 gateway endpoint |
| Data | `modules/database` | RDS PostgreSQL 16 in private subnets, SG-referenced ingress from ECS only |
| Compute | `modules/compute` | ECS Fargate Spot, ALB, ECR, IAM exec/task roles, CloudWatch logs, assets S3 bucket |
| Observability | `modules/observability` | CloudWatch alarms (ALB, RDS, NAT, ECS) → SNS |

Root `main.tf` is **composition-only** — no `resource` blocks at root.

## Cost estimate (~$132/mo target, $150/mo cap)

| Service | Configuration | Est. monthly |
|---------|---------------|--------------|
| NAT Gateway | 1× (single-AZ, cost trade-off) | ~$32 |
| ALB | 1× application LB | ~$22 |
| ECS Fargate Spot | 2× 0.25 vCPU / 0.5 GiB tasks | ~$18 |
| RDS PostgreSQL | db.t4g.micro, 20 GiB gp3, single-AZ | ~$15 |
| VPC interface endpoints | ECR×2, Secrets Manager, Logs | ~$28 |
| CloudWatch Logs | 14-day retention | ~$5 |
| S3 + DynamoDB state | bootstrap bucket + lock table | ~$2 |
| Data transfer / misc | conservative buffer | ~$10 |
| **Total** | | **~$132** |

### Cost trade-offs documented

- **Single NAT gateway** instead of per-AZ NAT saves ~$32/mo but creates cross-AZ egress for tasks in the non-NAT AZ (see `failure_domains` output).
- **Fargate Spot** for compute savings; tasks may be interrupted (acceptable for this sandbox API).
- **Single-AZ RDS** (`multi_az = false`) — upgrade for true DB HA if budget allows.
- **Interface VPC endpoints** add ~$28/mo but avoid NAT charges for ECR pulls and Secrets Manager access from private subnets.

## Quick start

See [RUNBOOK.md](./RUNBOOK.md) for the full clone → bootstrap → configure → init → plan → apply → smoke → destroy workflow.

```bash
# Static + API tests (no AWS creds required)
npm test
./scripts/verify.sh
```

## Remote state

1. `cd bootstrap && ../bin/terraform init && ../bin/terraform apply`
2. `./scripts/write-backend-config.sh <bucket> <lock-table>`
3. `../bin/terraform init -backend-config=backend.hcl`

## Project defaults

- `project_prefix = "northline"`
- `ecs_desired_count >= 2` (validated)
- ECS tasks: user `1000:1000`, `readonlyRootFilesystem`, health check via `api/healthcheck.sh`
- RDS: `manage_master_user_password = true`, no hardcoded credentials

## Repository layout

```
iac-prod/
├── bootstrap/          # S3 + DynamoDB for remote state
├── modules/            # networking, database, compute, observability
├── api/                # Node.js API + Dockerfile
├── scripts/            # backend config writer, verify harness
├── test/               # invariant + API tests
└── evidence/           # verification notes
```
