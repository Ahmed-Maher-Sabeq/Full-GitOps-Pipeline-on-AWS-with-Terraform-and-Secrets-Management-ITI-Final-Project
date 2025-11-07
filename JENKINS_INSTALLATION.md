# Jenkins Installation Guide

## Overview

Terraform creates the infrastructure and IAM roles. Jenkins is installed manually with Helm after infrastructure is ready.

## What Terraform Creates

✅ **IAM Policy** - `aws-gitops-pipeline-dev-jenkins-ecr-policy`
  - ECR authentication and push/pull permissions

✅ **IAM Role** - `aws-gitops-pipeline-dev-jenkins-role`
  - IRSA trust policy for `system:serviceaccount:jenkins:jenkins`
  - ECR policy attached

✅ **EBS CSI Driver** - For persistent storage
  - IAM role and policy
  - EKS addon installed

## Jenkins Installation (After Terraform)

### Prerequisites

After running `terraform apply`:

1. Configure kubectl:
```bash
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
```

2. Verify cluster access:
```bash
kubectl get nodes
```

3. Verify EBS CSI driver:
```bash
kubectl get pods -n kube-system | grep ebs-csi
```

### Install Jenkins with Helm

```bash
# Add Helm repo (if not already added)
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml \
  --version 5.7.15
```

### Wait for Jenkins to Start

```bash
# Watch pod status
kubectl get pods -n jenkins -w

# Expected: jenkins-0   2/2     Running   0
```

This takes about 2-3 minutes for plugins to install.

### Get Admin Password

```bash
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password
```

### Access Jenkins

```bash
# Port forward
kubectl --namespace jenkins port-forward svc/jenkins 8080:8080
```

Open: http://localhost:8080

## Configuration File

The `terraform/jenkins-helm-values.yaml` file contains:

- ✅ IRSA annotation with Jenkins IAM role ARN
- ✅ Jenkins 2.506-jdk17
- ✅ All required plugins (Kubernetes, Git, Docker, ECR, etc.)
- ✅ Persistent storage (10GB gp2)
- ✅ Dynamic Kubernetes agents
- ✅ Docker-in-Docker support
- ✅ Resource limits

## Verification

After installation:

```bash
# Check pod status
kubectl get pods -n jenkins

# Check service account has IRSA annotation
kubectl get sa jenkins -n jenkins -o yaml | grep role-arn

# Check persistent volume
kubectl get pvc -n jenkins

# Check all resources
kubectl get all -n jenkins
```

## Complete Deployment Flow

```bash
# 1. Deploy infrastructure
cd terraform
export TF_VAR_db_password="YourSecurePassword"
terraform apply -auto-approve

# 2. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster

# 3. Install Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml \
  --version 5.7.15

# 4. Wait for Jenkins
kubectl get pods -n jenkins -w

# 5. Get password
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password

# 6. Access Jenkins
kubectl --namespace jenkins port-forward svc/jenkins 8080:8080
```

## Why Manual Installation?

Terraform's Helm provider has issues when:
- Cluster doesn't exist yet during provider initialization
- Circular dependency between providers and resources
- Timing issues with cluster readiness

**Solution**: Terraform creates IAM roles, Helm installs Jenkins manually.

## Benefits

✅ **Terraform manages**: Infrastructure, IAM roles, EBS CSI driver
✅ **Helm manages**: Jenkins deployment and configuration
✅ **Clean separation**: Infrastructure vs application deployment
✅ **Reliable**: No provider initialization issues
✅ **Flexible**: Easy to update Jenkins independently

## Uninstall Jenkins

```bash
helm uninstall jenkins -n jenkins
```

Infrastructure remains intact. Reinstall anytime with the same command.

## Destroy Everything

```bash
# Uninstall Jenkins first
helm uninstall jenkins -n jenkins

# Then destroy infrastructure
cd terraform
terraform destroy -auto-approve
```

## Next Deployment

```bash
# 1. Deploy infrastructure
terraform apply -auto-approve

# 2. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster

# 3. Install Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml \
  --version 5.7.15
```

That's it! Simple and reliable.
