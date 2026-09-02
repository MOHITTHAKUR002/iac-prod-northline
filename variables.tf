variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier (e.g. us-east-1)."
  }
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

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability zones for subnet placement."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "availability_zones must include at least two AZs for subnet HA."
  }
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

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.db_instance_class))
    error_message = "db_instance_class must look like db.t4g.micro."
  }
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the public ALB (must be in the same region)."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:", var.acm_certificate_arn))
    error_message = "acm_certificate_arn must be a valid ACM certificate ARN."
  }
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GiB."
  type        = number
  default     = 20
}

variable "skip_final_snapshot" {
  description = "Allow destroy without final RDS snapshot (true for sandbox teardown)."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental RDS deletion (false for sandbox)."
  type        = bool
  default     = false
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
