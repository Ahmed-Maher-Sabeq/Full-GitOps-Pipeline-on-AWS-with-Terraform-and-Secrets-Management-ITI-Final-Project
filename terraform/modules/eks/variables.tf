# EKS Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS node group"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
}

variable "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EBS CSI Driver"
  type        = string
}
