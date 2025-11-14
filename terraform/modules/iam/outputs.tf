output "jenkins_role_arn" {
  description = "ARN of the Jenkins IAM role"
  value       = aws_iam_role.jenkins.arn
}

output "eso_role_arn" {
  description = "ARN of the External Secrets Operator IAM role"
  value       = aws_iam_role.eso.arn
}

output "aws_lb_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "argocd_image_updater_role_arn" {
  description = "ARN of the ArgoCD Image Updater IAM role"
  value       = aws_iam_role.argocd_image_updater.arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI Driver IAM role"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "nodejs_app_secrets_role_arn" {
  description = "ARN of the nodejs-app secrets IAM role"
  value       = aws_iam_role.nodejs_app_secrets.arn
}
