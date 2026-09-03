# RUNBOOK — Northline IaC

```bash
git clone https://github.com/MOHITTHAKUR002/iac-prod-northline iac-prod && cd iac-prod
npm test && ./scripts/verify.sh
cd bootstrap && ../bin/terraform init && ../bin/terraform apply -var="project_prefix=northline" && cd ..
./scripts/write-backend-config.sh "$(cd bootstrap && ../bin/terraform output -raw state_bucket_name)" "$(cd bootstrap && ../bin/terraform output -raw dynamodb_table_name)"
./bin/terraform init -backend-config=backend.hcl
./bin/terraform plan -var-file=terraform.tfvars | tee evidence/plan.txt && ./bin/terraform apply -var-file=terraform.tfvars
./bin/terraform destroy -var-file=terraform.tfvars
```

Cost ~$132/mo: single-AZ RDS (RPO ~5m, RTO 20-40m estimate), single NAT, Fargate on-demand base=1 + Spot weight (not Spot-only). Modules: networking, storage, database, load_balancing, compute, observability.
