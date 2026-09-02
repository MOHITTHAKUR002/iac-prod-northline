variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
}

variable "vpc_id" {
  description = "VPC identifier."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet identifiers for ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet identifiers for ECS tasks."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group identifier."
  type        = string
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

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:", var.acm_certificate_arn))
    error_message = "acm_certificate_arn must be a valid ACM certificate ARN."
  }
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
