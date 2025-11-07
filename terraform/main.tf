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
}


# EKS Module
module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

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


# Jenkins IAM Resources (Helm installation done manually)
# IAM Policy for Jenkins ECR Access
resource "aws_iam_policy" "jenkins_ecr" {
  name        = "${var.project_name}-${var.environment}-jenkins-ecr-policy"
  description = "Policy for Jenkins to access ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = module.ecr.repository_arn
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-ecr-policy"
  }
}

# IAM Role for Jenkins (IRSA)
resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:jenkins:jenkins"
            "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-role"
  }

  depends_on = [module.eks]
}

# Attach ECR policy to Jenkins role
resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins_ecr.arn
}
