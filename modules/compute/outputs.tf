output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.main.dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics."
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch metrics."
  value       = aws_lb_target_group.api.arn_suffix
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.api.name
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.api.repository_url
}

output "ecs_task_subnet_azs" {
  description = "Availability zones where ECS tasks may run."
  value       = [for s in data.aws_subnet.private : s.availability_zone]
}

output "assets_bucket_name" {
  description = "S3 assets bucket name."
  value       = aws_s3_bucket.assets.bucket
}
