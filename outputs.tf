output "vpc_id" {
  description = "VPC identifier."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet identifiers."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet identifiers."
  value       = module.networking.private_subnet_ids
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name."
  value       = module.compute.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for container images."
  value       = module.compute.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.compute.ecs_service_name
}

output "db_endpoint" {
  description = "RDS endpoint hostname."
  value       = module.database.db_endpoint
  sensitive   = true
}

output "db_port" {
  description = "RDS port."
  value       = module.database.db_port
}

output "failure_domains" {
  description = "AZ co-location report for NAT, RDS, and ECS tasks at apply time."
  value = {
    nat_gateway_az        = module.networking.nat_gateway_az
    rds_availability_zone = module.database.db_availability_zone
    ecs_subnet_azs        = module.compute.ecs_task_subnet_azs
    single_nat_risk       = length(distinct(concat([module.networking.nat_gateway_az], module.compute.ecs_task_subnet_azs))) > 1
    note                  = "Single NAT gateway saves ~$32/mo but creates cross-AZ egress for tasks in the non-NAT AZ."
  }
}

output "observability_sns_topic_arn" {
  description = "SNS topic for CloudWatch alarms."
  value       = module.observability.sns_topic_arn
}
