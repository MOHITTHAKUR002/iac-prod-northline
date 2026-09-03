# Northline Production Infrastructure

Terraform project that provisions a cost-conscious, production-style AWS environment for a containerized Node.js API backed by PostgreSQL.

**Repository:** https://github.com/MOHITTHAKUR002/iac-prod-northline

## Architecture

| Layer | Module | Key resources |
|-------|--------|---------------|
| Network | `modules/networking` | VPC, public/private subnets, single NAT, interface VPC endpoints, S3 gateway endpoint |
| Storage | `modules/storage` | Static-assets S3 bucket (SSE, public access block, versioning) |
| Data | `modules/database` | RDS PostgreSQL 16 in private subnets, SG-referenced ingress from ECS only |
| Edge | `modules/load_balancing` | ALB, target group, HTTPS (TLS 1.3) + HTTP→HTTPS redirect |
| Compute | `modules/compute` | ECS Fargate (on-demand base + Spot), ECR, IAM exec/task roles, CloudWatch logs |
| Observability | `modules/observability` | CloudWatch alarms (ALB, RDS, NAT, ECS) → SNS |

Root `main.tf` is **composition-only** — no `resource` blocks at root.

## Cost estimate (~$132/mo target, $150/mo cap)

| Service | Configuration | Est. monthly |
|---------|---------------|--------------|
| NAT Gateway | 1× (single-AZ, cost trade-off) | ~$32 |
| ALB | 1× application LB | ~$22 |
| ECS Fargate | 1× on-demand base + Spot remainder (0.25 vCPU / 0.5 GiB) | ~$20 |
| RDS PostgreSQL | db.t4g.micro, 20 GiB gp3, single-AZ | ~$15 |
| VPC interface endpoints | ECR×2, Secrets Manager, Logs | ~$28 |
| CloudWatch Logs | 14-day retention | ~$5 |
| S3 + DynamoDB state | bootstrap bucket + lock table | ~$2 |
| Data transfer / misc | conservative buffer | ~$10 |
| **Total** | | **~$132** |

### Cost trade-offs and operational consequences

| Trade-off | Savings | If it fails |
|-----------|---------|-------------|
| Single-AZ RDS | ~$14/mo vs Multi-AZ | **RPO ~5 min**, **RTO 20–40 min** (restore from snapshot + ECS redeploy; not drill-verified) |
| Single NAT | ~$32/mo vs 2× NAT | Cross-AZ egress dependency; endpoints cover AWS APIs |
| Fargate Spot (with on-demand base) | ~$4–8/mo vs all on-demand | Spot reclaim → temporary capacity drop; **≥1 on-demand task remains** |
| VPC interface endpoints | −$28/mo vs NAT-only | Keeps ECR/Secrets reachable if NAT AZ fails |

Full restore procedure and smoke-test steps: [RUNBOOK.md](./RUNBOOK.md).

## Before Caliber submission

1. Ensure GitHub remote is public: `https://github.com/MOHITTHAKUR002/iac-prod-northline`
2. `./scripts/capture-plan.sh` (requires AWS creds) → real `evidence/plan.txt`
3. `npm test && ./scripts/verify.sh`
4. `node scripts/build-submit.mjs` → review `SUBMIT_PREVIEW.json` (`plan ready: YES`)
5. **Ask agent to submit** only after you verify preview — do not submit with `PLAN PENDING`

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
- ALB: HTTPS (TLS 1.3) with `acm_certificate_arn`; HTTP redirects to HTTPS
- RDS: `manage_master_user_password = true`, no hardcoded credentials

## Repository layout

```
iac-prod/
├── bootstrap/              # S3 + DynamoDB for remote state
├── modules/
│   ├── networking/
│   ├── storage/
│   ├── database/
│   ├── load_balancing/
│   ├── compute/
│   └── observability/
├── api/                    # Node.js API + Dockerfile + healthcheck.sh
├── scripts/                # plan capture, verify, submit pack
├── evidence/               # plan.txt + VERIFY.md
├── ADR.md
├── RUNBOOK.md
└── README.md
```
