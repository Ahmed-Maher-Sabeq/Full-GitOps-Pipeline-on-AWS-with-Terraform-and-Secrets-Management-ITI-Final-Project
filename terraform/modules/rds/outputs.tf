# RDS Module Outputs

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "RDS instance address"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "db_secret_arn" {
  description = "ARN of RDS secret in Secrets Manager"
  value       = aws_secretsmanager_secret.rds.arn
}

output "db_secret_name" {
  description = "Name of RDS secret in Secrets Manager"
  value       = aws_secretsmanager_secret.rds.name
}
