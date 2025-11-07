# AWS GitOps Pipeline with Jenkins and ArgoCD

Complete AWS infrastructure with automated CI/CD pipeline using Jenkins and GitOps deployment with ArgoCD.

---

## 🎯 Current Status

**✅ COMPLETED:**
- Infrastructure deployed (VPC, EKS, RDS, ElastiCache, ECR)
- Jenkins installed on EKS with IRSA
- CI Pipeline working (Git → Jenkins → ECR)
- Docker images building and pushing to ECR

**⏳ NEXT:** ArgoCD setup for GitOps deployment

---

## 🏗️ Architecture

```
GitHub → Jenkins (CI) → ECR → ArgoCD (CD) → EKS
   ↓         ↓            ↓        ↓          ↓
  Code    Build+Test    Images   GitOps    Deploy
```

**Components:** VPC (3 AZs) • EKS (K8s 1.28) • RDS MySQL • ElastiCache Redis • ECR • Jenkins • ArgoCD

---

## 🚀 Quick Start (First Time)

### Prerequisites
- AWS CLI configured
- kubectl, Helm 3, Terraform installed

### Deploy Everything

```bash
# 1. Deploy infrastructure (15-20 min)
cd terraform
export TF_VAR_db_password="YourSecurePassword123!"
terraform init
terraform apply -auto-approve

# 2. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster

# 3. Install Jenkins (2-3 min)
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml

kubectl annotate serviceaccount jenkins -n jenkins \
  eks.amazonaws.com/role-arn=$(cd terraform && terraform output -raw jenkins_role_arn)
kubectl delete pod jenkins-0 -n jenkins
kubectl wait --for=condition=ready pod/jenkins-0 -n jenkins --timeout=300s

# 4. Get Jenkins password
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password

# 5. Access Jenkins (separate terminal)
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
```

### Create Pipeline

1. Open **http://localhost:8080** (admin / password from above)
2. New Item → `nodejs-app-git-pipeline` → Pipeline
3. Configure:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository: `https://github.com/YOUR_USERNAME/YOUR_REPO.git`
   - Branch: `*/main`
   - Script Path: `nodejs-app/Jenkinsfile`
4. Save → Build Now

### Verify

```bash
aws ecr describe-images --repository-name nodejs-app --region us-east-1
```

---

## ⚡ Quick Resume (After Destroy)

**Total time: ~20-25 minutes**

```bash
# 1. Deploy (15-20 min)
cd terraform
export TF_VAR_db_password="YourPassword"
terraform apply -auto-approve

# 2. Configure kubectl (30 sec)
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster

# 3. Install Jenkins (2-3 min)
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml

kubectl annotate serviceaccount jenkins -n jenkins \
  eks.amazonaws.com/role-arn=$(cd terraform && terraform output -raw jenkins_role_arn)
kubectl delete pod jenkins-0 -n jenkins
kubectl wait --for=condition=ready pod/jenkins-0 -n jenkins --timeout=300s

# 4. Access Jenkins
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password
kubectl port-forward svc/jenkins 8080:8080 -n jenkins  # separate terminal

# 5. Recreate pipeline (see above)
```

---

## 🔄 CI Pipeline Details

**Jenkinsfile:** `nodejs-app/Jenkinsfile`

**Stages:**
1. Checkout from Git
2. Verify files
3. Setup ECR auth (IRSA)
4. Build with Kaniko
5. Push to ECR (build-X + latest)

**Features:** Git-based • Kaniko (rootless) • IRSA (no credentials) • Multi-tag • K8s agents

**Output:** `287043460305.dkr.ecr.us-east-1.amazonaws.com/nodejs-app:build-X`

**Cache Warning:** Non-critical 403 on cache upload - images still build successfully

---

## 🗑️ Cleanup

### Before Destroy

```bash
# 1. Remove Jenkins
helm uninstall jenkins -n jenkins
kubectl wait --for=delete namespace/jenkins --timeout=120s

# 2. Optional: Delete ECR images
aws ecr batch-delete-image --repository-name nodejs-app --region us-east-1 \
  --image-ids "$(aws ecr list-images --repository-name nodejs-app --region us-east-1 --query 'imageIds[*]' --output json)"
```

### Destroy

```bash
cd terraform
export TF_VAR_db_password="YourPassword"
terraform destroy -auto-approve
```

**Time:** 10-15 minutes

---

## 🐛 Troubleshooting

### Jenkins pod stuck
```bash
kubectl describe pod jenkins-0 -n jenkins
kubectl get pvc -n jenkins
kubectl get pods -n kube-system | grep ebs-csi
```

### Pipeline fails (ECR 403)
```bash
kubectl get sa jenkins -n jenkins -o yaml | grep role-arn
kubectl annotate serviceaccount jenkins -n jenkins \
  eks.amazonaws.com/role-arn=$(cd terraform && terraform output -raw jenkins_role_arn) --overwrite
kubectl delete pod jenkins-0 -n jenkins
```

### Terraform destroy fails
```bash
# VPC dependency: Delete ENIs manually
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=<vpc-id>" --region us-east-1
aws ec2 delete-network-interface --network-interface-id <eni-id> --region us-east-1

# EKS stuck: Delete node group manually
aws eks delete-nodegroup --cluster-name gitops-eks-cluster --nodegroup-name <name> --region us-east-1
```

---

## 💰 Cost

**Monthly (running):** ~$237
- EKS: $73 • Nodes (2x t3.small): $30 • NAT (3x): $100 • RDS: $15 • Redis: $12 • Other: $7

**After destroy:** $0 (ECR images: ~$0.10/GB/month if not deleted)

---

## 🎯 Next Steps

Based on `.kiro/specs/aws-gitops-pipeline/tasks.md`:

### Phase 1: CI Pipeline ✅ COMPLETE
- [x] Terraform infrastructure
- [x] Jenkins on EKS with IRSA
- [x] Git-based pipeline with Kaniko
- [x] Push to ECR

### Phase 2: CD with ArgoCD (Next)
- [ ] Create Kubernetes manifests repository
- [ ] Install ArgoCD on EKS
- [ ] Configure ArgoCD application
- [ ] Set up automated sync from Git
- [ ] Deploy nodejs-app to EKS

### Phase 3: Image Automation
- [ ] Install Argo Image Updater
- [ ] Configure ECR monitoring
- [ ] Enable automatic image updates
- [ ] Test end-to-end GitOps flow

### Phase 4: Secrets Management
- [ ] Install External Secrets Operator
- [ ] Create IAM role for ESO
- [ ] Configure SecretStore for AWS Secrets Manager
- [ ] Create ExternalSecrets for RDS and Redis

### Phase 5: Ingress & TLS
- [ ] Install NGINX Ingress Controller
- [ ] Install cert-manager
- [ ] Create Ingress resource
- [ ] Configure Let's Encrypt TLS

---

## 📋 Quick Commands

```bash
# Jenkins password
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password

# Port forward
kubectl port-forward svc/jenkins 8080:8080 -n jenkins

# Check ECR
aws ecr describe-images --repository-name nodejs-app --region us-east-1

# Terraform outputs
cd terraform && terraform output
```

---

## 🔗 Key Info

- **Region:** us-east-1
- **Account:** 287043460305
- **EKS:** gitops-eks-cluster
- **ECR:** 287043460305.dkr.ecr.us-east-1.amazonaws.com/nodejs-app
- **Jenkins:** http://localhost:8080 (admin)

---

**Last Updated:** November 7, 2025  
**Status:** CI Working ✅ | Next: ArgoCD Setup
