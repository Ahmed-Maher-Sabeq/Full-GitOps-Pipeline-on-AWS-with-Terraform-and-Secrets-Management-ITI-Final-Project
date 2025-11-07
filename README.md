# AWS GitOps Pipeline with Jenkins and ArgoCD

Complete AWS infrastructure with automated CI/CD pipeline using Jenkins and GitOps deployment with ArgoCD.

## 🏗️ Architecture

- **VPC** - 3 public + 3 private subnets across 3 AZs
- **EKS** - Kubernetes 1.28 cluster with t3.small nodes
- **RDS** - MySQL database (Multi-AZ)
- **ElastiCache** - Redis cache
- **ECR** - Docker image registry
- **Jenkins** - CI pipeline (builds and pushes to ECR)
- **ArgoCD** - GitOps deployment (coming soon)

## 🚀 Quick Start

### Current Deployment Status ✅

**Infrastructure**: Deployed and Running  
**Jenkins**: Installed and Configured  
**Pipeline**: Successfully Built and Pushed to ECR  
**Latest Image**: `287043460305.dkr.ecr.us-east-1.amazonaws.com/nodejs-app:build-6`  
**Date**: November 7, 2025

### 1. Deploy Infrastructure

```bash
cd terraform
export TF_VAR_db_password="YourSecurePassword123!"
terraform init
terraform apply -auto-approve
```

⏱️ Takes ~15-20 minutes

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
kubectl get nodes
```

### 3. Install Jenkins

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml \
  --version 5.7.15

# Annotate service account with IAM role
kubectl annotate serviceaccount jenkins -n jenkins \
  eks.amazonaws.com/role-arn=arn:aws:iam::287043460305:role/aws-gitops-pipeline-dev-jenkins-role

# Restart Jenkins to pick up IAM role
kubectl delete pod jenkins-0 -n jenkins
```

⏱️ Takes ~2-3 minutes

### 4. Access Jenkins

```bash
# Get password
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password

# Port forward
kubectl --namespace jenkins port-forward svc/jenkins 8080:8080
```

Open: http://localhost:8080
- Username: `admin`
- Password: `pSmbIHLjhDHnms0OkKqJAz`

## 📁 Project Structure

```
.
├── terraform/                    # Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/                 # VPC and networking
│   │   ├── eks/                 # EKS cluster + EBS CSI driver
│   │   ├── rds/                 # MySQL database
│   │   ├── elasticache/         # Redis cache
│   │   └── ecr/                 # Container registry
│   ├── main.tf                  # Main configuration + Jenkins IAM
│   ├── provider.tf              # AWS provider
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   ├── terraform.tfvars         # Variable values
│   └── jenkins-helm-values.yaml # Jenkins Helm configuration
│
├── nodejs-app/                   # Sample Node.js application
│   ├── src/                     # Application code
│   ├── Dockerfile               # Container image
│   └── Jenkinsfile              # CI pipeline definition
│
├── jenkins/                      # Jenkins documentation
│   ├── QUICK_START.md           # Pipeline setup guide
│   └── JENKINS_SUMMARY.md       # Jenkins configuration details
│
├── JENKINS_INSTALLATION.md       # This guide
└── DEPLOYMENT_SUCCESS.md         # Current deployment status
```

## 📋 What Gets Created

### By Terraform (Automated)
- VPC with subnets, NAT gateway, Internet gateway
- EKS cluster with node group
- EBS CSI driver (IAM role + addon)
- RDS MySQL instance
- ElastiCache Redis cluster
- ECR repository
- **Jenkins IAM role with ECR permissions**
- All security groups and IAM policies

### By Helm (Manual)
- Jenkins deployment in Kubernetes
- Jenkins service account (with IRSA annotation)
- Jenkins persistent volume (10GB)
- Jenkins plugins and configuration

## 🔐 Security

- **IRSA** - IAM Roles for Service Accounts (no credentials in pods)
- **Private Subnets** - EKS nodes, RDS, and Redis in private subnets
- **Security Groups** - Restricted access between components
- **Secrets Manager** - Database credentials stored securely
- **Encrypted Storage** - RDS and EBS volumes encrypted

## 📊 Resources Created

| Component | Count | Type |
|-----------|-------|------|
| VPC | 1 | vpc |
| Subnets | 6 | 3 public + 3 private |
| EKS Cluster | 1 | Kubernetes 1.28 |
| EKS Nodes | 2 | t3.small |
| RDS | 1 | db.t3.micro (Multi-AZ) |
| Redis | 1 | cache.t3.micro |
| ECR | 1 | nodejs-app |
| IAM Roles | 4 | EKS, Nodes, EBS CSI, Jenkins |
| **Total** | **~50** | |

## 💰 Cost Estimate

Approximate monthly costs (us-east-1):

| Resource | Cost/Month |
|----------|------------|
| EKS Cluster | $73 |
| EC2 Nodes (2x t3.small) | $30 |
| NAT Gateways (3x) | $100 |
| RDS (db.t3.micro) | $15 |
| ElastiCache (cache.t3.micro) | $12 |
| EBS Volumes | $2 |
| **Total** | **~$232/month** |

💡 **Save costs**: Run `terraform destroy` when not using!

## 🔄 Daily Workflow

### Start of Day
```bash
cd terraform
export TF_VAR_db_password="YourPassword"
terraform apply -auto-approve

# Wait ~15 minutes, then:
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster

helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml \
  --version 5.7.15
```

### End of Day
```bash
helm uninstall jenkins -n jenkins
cd terraform
terraform destroy -auto-approve
```

## 📚 Documentation

- **JENKINS_INSTALLATION.md** - Jenkins installation guide (this file)
- **DEPLOYMENT_SUCCESS.md** - Current deployment status
- **terraform/QUICK_DEPLOY.md** - Quick reference commands
- **terraform/EBS_CSI_DRIVER.md** - EBS CSI driver details
- **jenkins/QUICK_START.md** - Jenkins pipeline setup
- **jenkins/JENKINS_SUMMARY.md** - Jenkins configuration details

## 🧪 Testing

### Verify Infrastructure

```bash
# Check Terraform outputs
cd terraform
terraform output

# Check EKS
kubectl get nodes
kubectl get pods --all-namespaces

# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
kubectl get csidriver

# Check ECR
aws ecr describe-repositories --repository-names nodejs-app --region us-east-1
```

### Verify Jenkins

```bash
# Check Jenkins pod
kubectl get pods -n jenkins

# Check service account IRSA
kubectl get sa jenkins -n jenkins -o yaml | grep role-arn

# Check persistent volume
kubectl get pvc -n jenkins
```

## 🐛 Troubleshooting

### Jenkins pod not starting

```bash
kubectl describe pod jenkins-0 -n jenkins
kubectl logs jenkins-0 -n jenkins -c init
```

### PVC stuck in Pending

```bash
kubectl get pvc -n jenkins
kubectl describe pvc jenkins -n jenkins
kubectl get pods -n kube-system | grep ebs-csi
```

### Cannot access ECR from Jenkins

```bash
kubectl get sa jenkins -n jenkins -o yaml
aws iam get-role --role-name aws-gitops-pipeline-dev-jenkins-role
```

## 🎯 Next Steps

1. ✅ Infrastructure deployed
2. ✅ Jenkins installed
3. ⏳ Create Jenkins pipeline job
4. ⏳ Test Docker build and ECR push
5. ⏳ Set up ArgoCD
6. ⏳ Deploy application to EKS

## 📞 Support

Check the documentation files for detailed guides:
- Infrastructure issues → `terraform/` docs
- Jenkins issues → `jenkins/` docs
- Pipeline issues → `nodejs-app/Jenkinsfile`

## 🔗 Current Deployment Details

### Infrastructure
- **VPC ID**: vpc-0e2d4c5b90f37dcba
- **EKS Cluster**: gitops-eks-cluster
- **Cluster Endpoint**: https://F67C3FCBC0FAE1D4EF3E4089267A2AD3.yl4.us-east-1.eks.amazonaws.com
- **Node Count**: 1 (t3.small)
- **Region**: us-east-1

### Databases
- **RDS Endpoint**: aws-gitops-pipeline-dev-mysql.cyhqco046hhu.us-east-1.rds.amazonaws.com:3306
- **Database Name**: appdb
- **Redis Endpoint**: gitops-redis.esvaw6.0001.use1.cache.amazonaws.com:6379

### Container Registry
- **ECR Repository**: 287043460305.dkr.ecr.us-east-1.amazonaws.com/nodejs-app

### Jenkins
- **Namespace**: jenkins
- **Status**: Running (2/2 containers)
- **Version**: 2.528.1 (Latest)
- **Chart Version**: 5.8.106
- **IAM Role**: arn:aws:iam::287043460305:role/aws-gitops-pipeline-dev-jenkins-role
- **Admin Password**: pSmbIHLjhDHnms0OkKqJAz
- **Plugins**: All latest versions (Kubernetes, Git, Docker Workflow, Pipeline AWS, Amazon ECR)

### Secrets Manager
- **RDS Credentials**: arn:aws:secretsmanager:us-east-1:287043460305:secret:aws-gitops-pipeline-dev-rds-credentials-BvJkRq
- **Redis Credentials**: arn:aws:secretsmanager:us-east-1:287043460305:secret:aws-gitops-pipeline-dev-redis-credentials-LlHdam
