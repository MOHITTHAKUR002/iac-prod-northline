variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
  default     = "northline"
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnet placement."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ecs_desired_count" {
  description = "Desired ECS task count (minimum 2 for HA)."
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_desired_count >= 2
    error_message = "ecs_desired_count must be at least 2 for high availability."
  }
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GiB."
  type        = number
  default     = 20
}

variable "container_image_tag" {
  description = "Docker image tag pushed to ECR."
  type        = string
  default     = "latest"
}

variable "alarm_email" {
  description = "Optional email for CloudWatch alarm notifications."
  type        = string
  default     = ""
}
