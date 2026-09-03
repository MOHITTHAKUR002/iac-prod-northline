# RUNBOOK — Northline IaC

```bash
git clone https://github.com/MOHITTHAKUR002/iac-prod-northline iac-prod && cd iac-prod
npm test && ./scripts/verify.sh
cd bootstrap && ../bin/terraform init && ../bin/terraform apply -var="project_prefix=northline" && cd ..
./scripts/write-backend-config.sh "$(cd bootstrap && ../bin/terraform output -raw state_bucket_name)" "$(cd bootstrap && ../bin/terraform output -raw dynamodb_table_name)"
./bin/terraform init -backend-config=backend.hcl
./bin/terraform plan -var-file=terraform.tfvars | tee evidence/plan.txt && ./bin/terraform apply -var-file=terraform.tfvars
./scripts/restore-rds.sh northline-prod-postgres   # RTO drill helper
./bin/terraform destroy -var-file=terraform.tfvars
```

~$132/mo itemized (NAT~32 ALB~22 Fargate~20-28 RDS~15 endpoints~28). Single-AZ RDS RPO~5m; RTO estimate 20-40m (often longer — see restore script). Single NAT + VPC endpoints. Fargate base=1 on-demand + Spot weight=3; Spot reclaim ~1-3m reduced capacity; autoscaling max=4. `var.container_port` wires SG+TG+task.
