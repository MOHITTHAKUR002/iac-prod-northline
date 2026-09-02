output "db_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.main.id
}

output "db_endpoint" {
  description = "RDS endpoint hostname."
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS port."
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.main.db_name
}

output "db_availability_zone" {
  description = "RDS instance availability zone."
  value       = aws_db_instance.main.availability_zone
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN for RDS master credentials."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
  sensitive   = true
}
