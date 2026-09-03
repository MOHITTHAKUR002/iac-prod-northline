# ADR-001 — Northline IaC

Accepted. Root main.tf composition-only. Modules: networking (VPC/NAT/SGs/endpoints), storage, database, load_balancing, compute (ECS/ECR/IAM only), observability.

Security: RDS manage_master_user_password; task secrets DB_USER/DB_PASSWORD from master_user_secret_arn; ECS 1000:1000; SourceArn on assume roles; no RunTask. Root var.container_port → SG+TG+task.

Cost ~$132/mo. Single-AZ RDS: RPO≈5m, RTO≈25–40m downtime until snapshot restore. Single NAT: cross-AZ egress outage until second NAT. Defaults skip_final_snapshot=false, deletion_protection=true. Capacity knobs: fargate_base/weight/spot_weight.
