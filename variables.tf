variable "aws_region" {
  type    = string
  default = "us-east-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.aws_region))
    error_message = "invalid region"
  }
}
variable "project_prefix" {
  type    = string
  default = "northline"
}
variable "environment" {
  type    = string
  default = "prod"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "invalid cidr"
  }
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "need >=2 AZs"
  }
}
variable "ecs_desired_count" {
  type    = number
  default = 2
  validation {
    condition     = var.ecs_desired_count >= 2
    error_message = "ecs_desired_count >= 2"
  }
}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.db_instance_class))
    error_message = "db.t4g.micro form"
  }
}
variable "acm_certificate_arn" {
  type = string
  validation {
    condition     = can(regex("^arn:aws:acm:", var.acm_certificate_arn))
    error_message = "need ACM ARN"
  }
}
variable "db_allocated_storage" {
  type    = number
  default = 20
}
variable "skip_final_snapshot" {
  type    = bool
  default = true
}
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "container_port" {
  type    = number
  default = 8080
  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "port 1024-65535"
  }
}
variable "container_image_tag" {
  type    = string
  default = "latest"
}
variable "ecs_max_capacity" {
  type    = number
  default = 4
  validation {
    condition     = var.ecs_max_capacity >= var.ecs_desired_count && var.ecs_max_capacity <= 10
    error_message = "ecs_max_capacity in [desired,10]"
  }
}
variable "alarm_email" {
  type    = string
  default = ""
}
