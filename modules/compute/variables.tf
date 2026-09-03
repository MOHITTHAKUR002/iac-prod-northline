variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks."
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "Security group for ECS task ENIs."
  type        = string
}

variable "ecs_desired_count" {
  description = "Desired ECS task count."
  type        = number

  validation {
    condition     = var.ecs_desired_count >= 2
    error_message = "ecs_desired_count must be at least 2 for high availability."
  }
}

variable "ecs_max_capacity" {
  description = "Autoscaling maximum task count."
  type        = number

  validation {
    condition     = var.ecs_max_capacity >= var.ecs_desired_count
    error_message = "ecs_max_capacity must be greater than or equal to ecs_desired_count."
  }
}

variable "fargate_base" {
  description = "On-demand FARGATE base capacity."
  type        = number
}

variable "fargate_weight" {
  description = "On-demand FARGATE weight."
  type        = number
}

variable "fargate_spot_weight" {
  description = "FARGATE_SPOT weight."
  type        = number
}

variable "container_port" {
  description = "Container listen port (must match networking SG and ALB target group)."
  type        = number
}

variable "container_image_tag" {
  description = "Docker image tag in ECR."
  type        = string
}

variable "db_endpoint" {
  description = "RDS endpoint hostname."
  type        = string
}

variable "db_port" {
  description = "RDS port."
  type        = number
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "master_user_secret_arn" {
  description = "Secrets Manager ARN for RDS master user credentials (manage_master_user_password)."
  type        = string
}

variable "assets_bucket_arn" {
  description = "ARN of the static assets S3 bucket."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN."
  type        = string
}
