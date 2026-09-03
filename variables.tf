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
  description = "Availability zones for subnet placement (minimum two)."
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

variable "ecs_max_capacity" {
  description = "ECS autoscaling ceiling (keeps spend under the $150/mo cap)."
  type        = number
  default     = 4

  validation {
    condition     = var.ecs_max_capacity >= var.ecs_desired_count && var.ecs_max_capacity <= 10
    error_message = "ecs_max_capacity must be between ecs_desired_count and 10."
  }
}

variable "fargate_base" {
  description = "On-demand FARGATE capacity-provider base (guaranteed tasks)."
  type        = number
  default     = 1

  validation {
    condition     = var.fargate_base >= 1
    error_message = "fargate_base must be at least 1 so HA is not Spot-only."
  }
}

variable "fargate_weight" {
  description = "On-demand FARGATE capacity-provider weight."
  type        = number
  default     = 1
}

variable "fargate_spot_weight" {
  description = "FARGATE_SPOT capacity-provider weight (cost trade-off)."
  type        = number
  default     = 3
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
  description = "ACM certificate ARN for HTTPS on the public ALB."
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
  description = "Skip final RDS snapshot on destroy. Default false so backup reliance stays honest; set true only for sandbox teardown."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Prevent accidental RDS deletion. Default true for production; set false only for sandbox teardown."
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Container listen port — single source of truth for SG ingress, ALB target group, and ECS task."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "container_port must be a non-privileged TCP port (1024-65535)."
  }
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
