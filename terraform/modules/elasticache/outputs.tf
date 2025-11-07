# ElastiCache Module Outputs

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].port
}

output "redis_secret_arn" {
  description = "ARN of Redis secret in Secrets Manager"
  value       = aws_secretsmanager_secret.redis.arn
}

output "redis_secret_name" {
  description = "Name of Redis secret in Secrets Manager"
  value       = aws_secretsmanager_secret.redis.name
}
