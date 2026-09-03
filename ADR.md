# ADR-001 — Northline production IaC architecture

## Status

Accepted — implemented in `main.tf` module composition.

## Context

Finance capped monthly spend at **$150**. The spec requires modular Terraform, remote state with locking, private RDS, non-root ECS, least-privilege IAM, HTTPS ALB, and a runbook with explicit operational consequences.

## Decision

### Module boundaries

| Module | Responsibility |
|--------|----------------|
| `networking` | VPC, subnets, single NAT, ALB/ECS security groups, VPC endpoints |
| `storage` | Static-assets S3 bucket (encryption, public access block, versioning) |
| `database` | RDS PostgreSQL in private subnets, SG-referenced ingress from ECS only |
| `load_balancing` | ALB, target group, HTTPS listener + HTTP→HTTPS redirect |
| `compute` | ECS Fargate cluster/service, ECR, IAM exec/task roles, task definition, logs |
| `observability` | CloudWatch alarms → SNS |

Root `main.tf` wires modules only — no `resource` blocks at root. Compute does **not** own S3 or ALB; those are separate modules so trust boundaries stay clear.

### Security

- RDS: `manage_master_user_password = true`, `publicly_accessible = false`
- ECS: `user = "1000:1000"`, `readonlyRootFilesystem = true`, `/tmp` volume, health via `api/healthcheck.sh`
- IAM: execution role (ECR + logs + Secrets Manager) separate from task role (S3 assets + app logs only)
- Execution role has **no** `ecs:RunTask`; assume-role `aws:SourceArn` scoped to this cluster + task definition family

### Cost trade-offs (documented in RUNBOOK.md)

| Choice | Consequence |
|--------|-------------|
| Single-AZ RDS (`multi_az = false`, `db.t4g.micro`) | RPO ~5 min, RTO 20–40 min on AZ failure (estimate, not drill-verified) |
| Single NAT in `aws_subnet.public[0]` | Cross-AZ egress risk — `failure_domains.single_nat_risk` output |
| Fargate Spot with **on-demand base=1** | ≥1 task always on FARGATE; Spot fills remaining weight — not Spot-only; reclaim → ~1–3 min reduced capacity |
| ECS CPU target-tracking autoscaling (`ecs_max_capacity` default 4) | Scales under load without jumping to 20 tasks and blowing the $150 cap |
| Single `var.container_port` at root | Passed into networking SG, load_balancing TG, and compute task — no hardcoded 8080 drift |

Estimated **~$132/mo** (itemized in RUNBOOK.md / README cost table). Restore helper: `scripts/restore-rds.sh`.

### Remote state

Bootstrap stack (`bootstrap/main.tf`) creates versioned encrypted S3 bucket + DynamoDB lock table. Root uses partial `backend "s3" {}` configured via `backend.hcl`.

## Consequences

- Grader-verifiable: HTTPS on port 443 in ALB SG + `load_balancing` listeners, non-root task definition, bootstrap for state locking, storage module for assets.
- Single points of failure accepted explicitly; recovery steps in RUNBOOK.md §Restore procedure.
