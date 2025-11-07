# Project Configuration
project_name = "aws-gitops-pipeline"
environment  = "dev"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

# EKS Configuration
cluster_name         = "gitops-eks-cluster"
cluster_version      = "1.28"
node_instance_types  = ["t3.small"]
node_desired_size    = 2
node_min_size        = 1
node_max_size        = 4

# RDS Configuration
db_name              = "appdb"
db_username          = "admin"
# db_password should be set via environment variable: TF_VAR_db_password
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_engine_version    = "8.0"

# ElastiCache Configuration
redis_cluster_id      = "gitops-redis"
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 1
redis_engine_version  = "7.0"

# ECR Configuration
ecr_repository_name = "nodejs-app"
