variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet identifiers for ECS tasks."
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "ECS tasks security group identifier."
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

variable "assets_bucket_arn" {
  description = "ARN of the static assets S3 bucket (storage module)."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN (load_balancing module)."
  type        = string
}
