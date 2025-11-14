variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN of RDS secret in Secrets Manager"
  type        = string
}

variable "redis_secret_arn" {
  description = "ARN of Redis secret in Secrets Manager"
  type        = string
}
