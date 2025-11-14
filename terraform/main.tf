# Main Terraform Configuration

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.cluster_name
}


# EKS Module
module "eks" {
  source = "./modules/eks"

  project_name             = var.project_name
  environment              = var.environment
  cluster_name             = var.cluster_name
  cluster_version          = var.cluster_version
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  node_instance_types      = var.node_instance_types
  node_desired_size        = var.node_desired_size
  node_min_size            = var.node_min_size
  node_max_size            = var.node_max_size
  ebs_csi_driver_role_arn  = module.iam.ebs_csi_driver_role_arn

  depends_on = [module.vpc]
}


# RDS Module
module "rds" {
  source = "./modules/rds"

  project_name                = var.project_name
  environment                 = var.environment
  db_name                     = var.db_name
  db_username                 = var.db_username
  db_password                 = var.db_password
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  allowed_security_group_ids  = [module.eks.node_security_group_id]
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  engine_version              = var.db_engine_version

  depends_on = [module.vpc, module.eks]
}


# ElastiCache Module
module "elasticache" {
  source = "./modules/elasticache"

  project_name                = var.project_name
  environment                 = var.environment
  cluster_id                  = var.redis_cluster_id
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  allowed_security_group_ids  = [module.eks.node_security_group_id]
  node_type                   = var.redis_node_type
  num_cache_nodes             = var.redis_num_cache_nodes
  engine_version              = var.redis_engine_version

  depends_on = [module.vpc, module.eks]
}


# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name    = var.project_name
  environment     = var.environment
  repository_name = var.ecr_repository_name
}


# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name        = var.project_name
  environment         = var.environment
  oidc_provider_arn   = module.eks.oidc_provider_arn
  ecr_repository_arn  = module.ecr.repository_arn
  rds_secret_arn      = module.rds.db_secret_arn
  redis_secret_arn    = module.elasticache.redis_secret_arn
}
