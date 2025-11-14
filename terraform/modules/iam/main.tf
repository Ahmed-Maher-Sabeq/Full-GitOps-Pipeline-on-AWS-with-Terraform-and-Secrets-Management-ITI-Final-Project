# IAM Module for GitOps Pipeline
# This module creates all IAM roles and policies for the pipeline

# Jenkins IAM Resources
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
        Resource = var.ecr_repository_arn
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-ecr-policy"
  }
}

resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:jenkins:jenkins"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-role"
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins_ecr.arn
}

# External Secrets Operator IAM Resources
resource "aws_iam_policy" "eso_secrets_manager" {
  name        = "${var.project_name}-${var.environment}-eso-secrets-policy"
  description = "Policy for External Secrets Operator to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.rds_secret_arn,
          var.redis_secret_arn
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-eso-secrets-policy"
  }
}

resource "aws_iam_role" "eso" {
  name = "${var.project_name}-${var.environment}-eso-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:nodejs-app:nodejs-app-sa"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-eso-role"
  }
}

resource "aws_iam_role_policy_attachment" "eso_secrets_manager" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso_secrets_manager.arn
}

# AWS Load Balancer Controller IAM Resources
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.project_name}-${var.environment}-aws-lb-controller-policy"
  description = "Policy for AWS Load Balancer Controller"

  policy = file("${path.module}/policies/aws-lb-controller-policy.json")

  tags = {
    Name = "${var.project_name}-${var.environment}-aws-lb-controller-policy"
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-${var.environment}-aws-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-aws-lb-controller-role"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# ArgoCD Image Updater IAM Resources
resource "aws_iam_policy" "argocd_image_updater_ecr" {
  name        = "${var.project_name}-${var.environment}-argocd-image-updater-ecr-policy"
  description = "Policy for ArgoCD Image Updater to access ECR"

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
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-argocd-image-updater-ecr-policy"
  }
}

resource "aws_iam_role" "argocd_image_updater" {
  name = "${var.project_name}-${var.environment}-argocd-image-updater-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:argocd:argocd-image-updater"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-argocd-image-updater-role"
  }
}

resource "aws_iam_role_policy_attachment" "argocd_image_updater_ecr" {
  role       = aws_iam_role.argocd_image_updater.name
  policy_arn = aws_iam_policy.argocd_image_updater_ecr.arn
}

# EBS CSI Driver IAM Resources
resource "aws_iam_policy" "ebs_csi_driver" {
  name        = "${var.project_name}-${var.environment}-ebs-csi-driver-policy"
  description = "Policy for EBS CSI Driver"

  policy = file("${path.module}/policies/ebs-csi-driver-policy.json")

  tags = {
    Name = "${var.project_name}-${var.environment}-ebs-csi-driver-policy"
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.project_name}-${var.environment}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ebs-csi-driver-role"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = aws_iam_policy.ebs_csi_driver.arn
}

# nodejs-app External Secrets IAM Resources
resource "aws_iam_policy" "nodejs_app_secrets" {
  name        = "${var.project_name}-${var.environment}-nodejs-app-secrets-policy"
  description = "Policy for nodejs-app to access Secrets Manager via External Secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.rds_secret_arn,
          var.redis_secret_arn
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-nodejs-app-secrets-policy"
  }
}

resource "aws_iam_role" "nodejs_app_secrets" {
  name = "nodejs-app-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:nodejs-app:nodejs-app-sa"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "nodejs-app-secrets-role"
  }
}

resource "aws_iam_role_policy_attachment" "nodejs_app_secrets" {
  role       = aws_iam_role.nodejs_app_secrets.name
  policy_arn = aws_iam_policy.nodejs_app_secrets.arn
}
