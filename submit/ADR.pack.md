# ADR-001 — Northline IaC

Accepted. Root main.tf composition-only. Modules: networking (VPC/NAT/SGs/endpoints), storage, database, load_balancing, compute (ECS/ECR/IAM only), observability.

Security: RDS manage_master_user_password; ECS 1000:1000; exec≠task; SourceArn on both assume roles; no RunTask on exec. Root var.container_port → SG+TG+task.

Cost ~$132/mo itemized: single-AZ RDS (RPO~5m; restore via scripts/restore-rds.sh), single NAT + endpoints, Fargate base=1 + Spot, autoscaling max=4.
