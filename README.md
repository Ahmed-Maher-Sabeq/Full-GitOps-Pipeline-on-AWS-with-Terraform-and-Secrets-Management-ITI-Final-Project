# AWS GitOps Pipeline - Complete CI/CD with Jenkins & ArgoCD

Full AWS infrastructure with Jenkins CI and ArgoCD CD pipeline using GitOps methodology.

---

## 🎯 Current Status

**✅ COMPLETED:**
- Terraform infrastructure (VPC, EKS, RDS, Redis, ECR)
- EKS nodes configured for 110 pods each
- Jenkins CI pipeline (Git → Build → ECR)
- ArgoCD CD pipeline (Git → Sync → EKS)
- External Secrets Operator (AWS Secrets Manager → K8s Secrets)
- Kubernetes manifests for nodejs-app

**⚠️ KNOWN ISSUE:**
- ESO webhook pod not starting (cert-controller pending)
- Workaround: Apply manifests directly or fix webhook

**⏳ NEXT:** Fix ESO webhook or apply secrets manually

---

## 🚀 Complete Deployment Guide

### Prerequisites
- AWS CLI configured
- kubectl, Helm 3, Terraform installed
- Git repo: https://github.com/Ahmed-Maher-Sabeq/Full-GitOps-Pipeline-on-AWS-with-Terraform-and-Secrets-Management-ITI-Final-Project.git

### Step 1: Deploy Infrastructure (15-20 min)

**PowerShell:**
```powershell
cd terraform
$env:TF_VAR_db_password="YourSecurePassword123!"
terraform init
terraform apply -auto-approve
```

**Linux/Mac:**
```bash
cd terraform
export TF_VAR_db_password="YourSecurePassword123!"
terraform init
terraform apply -auto-approve
```

**Creates:** VPC • EKS (2 nodes, 110 pods each) • RDS • Redis • ECR • IAM roles

### Step 2: Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
kubectl get nodes  # Should show 2 nodes
```

### Step 3: Install Jenkins (2-3 min)

**PowerShell:**
```powershell
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm install jenkins jenkins/jenkins `
  --namespace jenkins `
  --create-namespace `
  --values terraform/jenkins-helm-values.yaml

# Get IAM role ARN
cd terraform
$ROLE_ARN = terraform output -raw jenkins_role_arn
cd ..

# Annotate service account
kubectl annotate serviceaccount jenkins -n jenkins `
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite

# Restart Jenkins
kubectl delete pod jenkins-0 -n jenkins
kubectl wait --for=condition=ready pod/jenkins-0 -n jenkins --timeout=300s
```

**Linux/Mac:**
```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml

# Get IAM role ARN
ROLE_ARN=$(cd terraform && terraform output -raw jenkins_role_arn)

# Annotate service account
kubectl annotate serviceaccount jenkins -n jenkins \
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite

# Restart Jenkins
kubectl delete pod jenkins-0 -n jenkins
kubectl wait --for=condition=ready pod/jenkins-0 -n jenkins --timeout=300s
```

### Step 4: Access Jenkins

**Get password:**
```bash
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password
```

**Port forward (separate terminal):**
```bash
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
```

**URL:** http://localhost:8080  
**Username:** admin  
**Password:** (from command above)

### Step 5: Create Jenkins Pipeline

1. Click **New Item** → `nodejs-app-git-pipeline` → **Pipeline**
2. Configure:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository: `https://github.com/Ahmed-Maher-Sabeq/Full-GitOps-Pipeline-on-AWS-with-Terraform-and-Secrets-Management-ITI-Final-Project.git`
   - Branch: `*/main`
   - Script Path: `nodejs-app/Jenkinsfile`
3. Save → Build Now

**Verify:**
```bash
aws ecr describe-images --repository-name nodejs-app --region us-east-1
```

### Step 6: Install ArgoCD (2-3 min)

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=ClusterIP

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s
```

### Step 7: Access ArgoCD

**PowerShell:**
```powershell
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | ForEach-Object { `
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**Linux/Mac:**
```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**Port forward (separate terminal - use different port than Jenkins):**
```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

**URL:** https://localhost:8081  
**Username:** admin  
**Password:** (from command above)

### Step 8: Deploy Application with ArgoCD

```bash
kubectl apply -f k8s/argocd/application.yaml
```

**Check status:**
```bash
kubectl get application -n argocd
kubectl get pods -n nodejs-app
```

### Step 9: Install External Secrets Operator

```bash
kubectl create namespace external-secrets-system

helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=external-secrets \
  -n external-secrets-system --timeout=300s
```

**Note:** ESO webhook may have issues. Secrets will sync once webhook is healthy.

### Step 10: Verify Deployment

```bash
# Check all components
kubectl get pods -n jenkins
kubectl get pods -n argocd
kubectl get pods -n external-secrets-system
kubectl get pods -n nodejs-app

# Check secrets (once ESO webhook is healthy)
kubectl get secrets -n nodejs-app
kubectl get externalsecrets -n nodejs-app
```

---

## 📁 Project Structure

```
.
├── terraform/                    # Infrastructure
│   ├── modules/
│   │   ├── vpc/                 # Networking
│   │   ├── eks/                 # EKS + Launch Template (110 pods)
│   │   ├── rds/                 # MySQL
│   │   ├── elasticache/         # Redis
│   │   └── ecr/                 # Container registry
│   ├── main.tf                  # Main + IAM roles
│   ├── outputs.tf               # Outputs
│   └── jenkins-helm-values.yaml # Jenkins config
│
├── k8s/                          # Kubernetes manifests
│   ├── application/
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml  # With ESO IAM role
│   │   ├── deployment.yaml      # 3 replicas
│   │   ├── service.yaml
│   │   ├── secretstore.yaml     # AWS Secrets Manager
│   │   ├── externalsecret-rds.yaml
│   │   └── externalsecret-redis.yaml
│   └── argocd/
│       └── application.yaml     # ArgoCD app definition
│
├── nodejs-app/                   # Application
│   ├── src/                     # Node.js code
│   ├── Dockerfile               # Container image
│   └── Jenkinsfile              # CI pipeline (Kaniko)
│
└── README.md                     # This file
```

---

## 🔄 Complete CI/CD Flow

```
1. Developer pushes code to GitHub
   ↓
2. Jenkins pipeline triggers
   ↓
3. Kaniko builds Docker image (rootless)
   ↓
4. Image pushed to ECR (build-X + latest tags)
   ↓
5. ArgoCD detects Git changes
   ↓
6. ArgoCD syncs manifests to EKS
   ↓
7. ESO creates secrets from AWS Secrets Manager
   ↓
8. Pods start with secrets mounted
   ↓
9. Application running on EKS
```

---

## 🔐 Security Features

- **IRSA** - IAM roles for Jenkins & ESO (no stored credentials)
- **Private Subnets** - EKS nodes, RDS, Redis isolated
- **Secrets Manager** - Credentials stored securely in AWS
- **Kaniko** - Rootless container builds
- **GitOps** - Declarative, auditable deployments
- **Encrypted Storage** - RDS and EBS encrypted

---

## 💰 Cost Estimate

**Monthly (running):** ~$237
- EKS: $73
- Nodes (2x t3.small): $30
- NAT Gateway: $33
- RDS: $15
- Redis: $12
- Other: $74

**After destroy:** $0

---

## 🗑️ Cleanup

### Before Destroy

```bash
# Remove Helm releases
helm uninstall jenkins -n jenkins
helm uninstall argocd -n argocd
helm uninstall external-secrets -n external-secrets-system

# Delete ECR images (optional)
aws ecr batch-delete-image --repository-name nodejs-app --region us-east-1 \
  --image-ids imageTag=latest
```

### Destroy Infrastructure

**PowerShell:**
```powershell
cd terraform
$env:TF_VAR_db_password="YourPassword"
terraform destroy -auto-approve
```

**Linux/Mac:**
```bash
cd terraform
export TF_VAR_db_password="YourPassword"
terraform destroy -auto-approve
```

**Time:** 10-15 minutes

---

## 🐛 Troubleshooting

### Jenkins Issues

**Pod stuck pending:**
```bash
kubectl describe pod jenkins-0 -n jenkins
kubectl get pvc -n jenkins
```

**Pipeline fails (ECR 403):**

PowerShell:
```powershell
cd terraform
$ROLE_ARN = terraform output -raw jenkins_role_arn
cd ..
kubectl annotate serviceaccount jenkins -n jenkins `
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
kubectl delete pod jenkins-0 -n jenkins
```

Linux/Mac:
```bash
ROLE_ARN=$(cd terraform && terraform output -raw jenkins_role_arn)
kubectl annotate serviceaccount jenkins -n jenkins \
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
kubectl delete pod jenkins-0 -n jenkins
```

### ArgoCD Issues

**Application OutOfSync:**
```bash
# Trigger manual sync
kubectl patch application nodejs-app -n argocd \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}' \
  --type merge
```

**Can't access UI:**
```bash
# Check pod status
kubectl get pods -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### ESO Issues

**Webhook not ready:**
```bash
# Check webhook pod
kubectl get pods -n external-secrets-system
kubectl describe pod -n external-secrets-system \
  -l app.kubernetes.io/name=external-secrets-webhook

# Workaround: Apply secrets manually
kubectl create secret generic rds-secret -n nodejs-app \
  --from-literal=DB_HOST=<rds-endpoint> \
  --from-literal=DB_PORT=3306 \
  --from-literal=DB_NAME=appdb \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=<password>
```

### Pods Not Starting

**Check secrets:**
```bash
kubectl get secrets -n nodejs-app
kubectl describe pod -n nodejs-app
```

**Check ESO sync:**
```bash
kubectl get externalsecrets -n nodejs-app
kubectl describe externalsecret rds-external-secret -n nodejs-app
```

---

## 📊 Key Resources

### AWS
- **Region:** us-east-1
- **Account:** 287043460305
- **EKS:** gitops-eks-cluster (2 nodes, 110 pods each)
- **ECR:** 287043460305.dkr.ecr.us-east-1.amazonaws.com/nodejs-app

### Jenkins
- **URL:** http://localhost:8080
- **Namespace:** jenkins
- **IAM Role:** aws-gitops-pipeline-dev-jenkins-role

### ArgoCD
- **URL:** https://localhost:8081
- **Namespace:** argocd
- **Application:** nodejs-app

### Application
- **Namespace:** nodejs-app
- **Replicas:** 3
- **Service:** ClusterIP on port 80
- **IAM Role:** aws-gitops-pipeline-dev-eso-role

---

## 🎯 What We Built

### Phase 1: Infrastructure ✅
- VPC with public/private subnets
- EKS cluster with custom launch template (110 pods/node)
- RDS MySQL (Multi-AZ)
- ElastiCache Redis
- ECR repository
- IAM roles (Jenkins, ESO)

### Phase 2: CI Pipeline ✅
- Jenkins on EKS
- Git-based Jenkinsfile
- Kaniko for rootless builds
- Automated push to ECR
- IRSA for AWS access

### Phase 3: CD Pipeline ✅
- ArgoCD on EKS
- GitOps sync from GitHub
- Automated deployment
- Self-healing enabled

### Phase 4: Secrets Management ✅
- External Secrets Operator
- AWS Secrets Manager integration
- IRSA for ESO
- Automatic secret sync

### Phase 5: Application ✅
- Node.js app with Express
- MySQL and Redis integration
- Health checks
- 3 replicas for HA

---

## 🎯 What's Next

Based on `.kiro/specs/aws-gitops-pipeline/tasks.md`, here are the remaining phases:

### Phase 6: Image Automation (Task 16)
- [ ] Install Argo Image Updater
- [ ] Configure Image Updater for ECR monitoring
- [ ] Add annotations to ArgoCD Application
- [ ] Enable automatic image updates on new builds
- [ ] Test end-to-end: Git push → Jenkins build → ECR push → Auto deploy

**Goal:** Automatically update deployments when Jenkins pushes new images to ECR

### Phase 7: Ingress & TLS (Tasks 18-20)
- [ ] Install NGINX Ingress Controller
- [ ] Verify AWS Load Balancer creation
- [ ] Install cert-manager for TLS
- [ ] Create ClusterIssuer for Let's Encrypt
- [ ] Create Ingress resource with TLS
- [ ] Configure DNS to point to Load Balancer
- [ ] Test HTTPS access to application

**Goal:** Expose application via HTTPS with automatic TLS certificates

### Phase 8: Fix Current Issues
- [ ] Fix ESO webhook (cert-controller pod pending)
- [ ] Verify secrets sync from AWS Secrets Manager
- [ ] Ensure all pods are running healthy
- [ ] Test complete application flow (DB + Redis)

**Goal:** Get the application fully operational

### Phase 9: Documentation & Polish
- [ ] Create architecture diagram
- [ ] Document complete CI/CD flow
- [ ] Add troubleshooting guides
- [ ] Create demo/testing procedures

**Goal:** Complete, production-ready documentation

---

## 📝 Important Notes

### Terraform State
- Stored locally in `terraform/terraform.tfstate`
- **Don't delete** or you'll lose track of resources

### Jenkins Persistence
- Data in Kubernetes PVC
- Deleted with `helm uninstall`

### ECR Images
- Persist after `terraform destroy`
- Delete manually if needed

### ESO Webhook Issue
- Known issue with cert-controller pod
- Secrets won't sync until webhook is healthy
- Workaround: Apply secrets manually

### Node Capacity
- Each node supports 110 pods (custom launch template)
- 2 nodes = 220 total pod capacity
- Current usage: ~15-20 pods

---

## 🔗 Quick Commands

**Get Jenkins password:**
```bash
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password
```

**Get ArgoCD password (PowerShell):**
```powershell
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | ForEach-Object { `
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**Get ArgoCD password (Linux/Mac):**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**Port forwards:**
```bash
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

**Check everything:**
```bash
kubectl get pods --all-namespaces
kubectl get application -n argocd
kubectl get externalsecrets -n nodejs-app
```

**Terraform outputs:**
```bash
cd terraform && terraform output
```

---

## 🚀 Next Session Checklist

When you return tomorrow:

1. **Deploy infrastructure** (~20 min)
   
   PowerShell:
   ```powershell
   cd terraform
   $env:TF_VAR_db_password="YourPassword"
   terraform apply -auto-approve
   ```
   
   Linux/Mac:
   ```bash
   cd terraform
   export TF_VAR_db_password="YourPassword"
   terraform apply -auto-approve
   ```

2. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
   ```

3. **Install Jenkins** (~3 min) - See Step 3 above

4. **Install ArgoCD** (~3 min) - See Step 6 above

5. **Install ESO** (~2 min) - See Step 9 above

6. **Fix ESO webhook issue** - Main task for next session

7. **Verify application** - Check pods are running

**Total time to resume:** ~30 minutes

---

**Last Updated:** November 9, 2025  
**Status:** Infrastructure ready • CI/CD working • ESO webhook needs fix  
**Next:** Fix ESO webhook or apply secrets manually to start app
