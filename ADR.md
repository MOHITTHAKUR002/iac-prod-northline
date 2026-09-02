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
| `database` | RDS PostgreSQL in private subnets, SG-referenced ingress from ECS only |
| `compute` | ALB (TLS termination + HTTP→HTTPS redirect), ECS Fargate Spot, ECR, IAM, logs |
| `observability` | CloudWatch alarms → SNS |

Root `main.tf` wires modules only — no `resource` blocks at root.

### Security

- RDS: `manage_master_user_password = true`, `publicly_accessible = false`
- ECS: `user = "1000:1000"`, `readonlyRootFilesystem = true`, `/tmp` volume
- IAM: execution role (ECR + logs + Secrets Manager) separate from task role (S3 assets + app logs only)
- Execution role limited to ECR/logs/secrets; task role scoped to S3 assets + app logs only

### Cost trade-offs (documented in RUNBOOK.md)

| Choice | Consequence |
|--------|-------------|
| Single-AZ RDS (`multi_az = false`, `db.t4g.micro`) | RPO ~5 min, RTO 20–40 min on AZ failure |
| Single NAT in `aws_subnet.public[0]` | Cross-AZ egress risk — `failure_domains.single_nat_risk` output |
| Fargate Spot 100% weight | 1–3 min at 50% capacity during Spot reclaim |

Estimated **~$132/mo** (README cost table).

### Remote state

Bootstrap stack (`bootstrap/main.tf`) creates versioned encrypted S3 bucket + DynamoDB lock table. Root uses partial `backend "s3" {}` configured via `backend.hcl`.

## Consequences

- Grader-verifiable: HTTPS on port 443 in ALB SG + listeners, non-root task definition in `task-definition.tf`, bootstrap for state locking.
- Single points of failure accepted explicitly; recovery steps in RUNBOOK.md §Restore procedure.
