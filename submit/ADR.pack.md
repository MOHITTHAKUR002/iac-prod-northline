# ADR-001 — Northline IaC

Accepted. Root main.tf is composition-only.

| Module | Owns |
|--------|------|
| networking | VPC, subnets, single NAT, SGs, VPC endpoints |
| storage | Static-assets S3 (SSE, PAB, versioning) |
| database | Private RDS Postgres, SG ingress from ECS only |
| load_balancing | ALB, TG, HTTPS + HTTP→HTTPS |
| compute | ECS/ECR/IAM/logs/task def (no S3, no ALB) |
| observability | CloudWatch alarms → SNS |

Security: RDS manage_master_user_password; ECS user 1000:1000 + readonlyRootFilesystem; exec role ≠ task role (no RunTask on exec).

Cost (~$132/mo): single-AZ RDS (RPO~5m, RTO 20–40m estimate), single NAT, Fargate base=1 + Spot weight.
