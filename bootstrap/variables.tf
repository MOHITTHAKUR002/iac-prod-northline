variable "aws_region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Short prefix used in bucket and table names."
  type        = string
  default     = "northline"
}
