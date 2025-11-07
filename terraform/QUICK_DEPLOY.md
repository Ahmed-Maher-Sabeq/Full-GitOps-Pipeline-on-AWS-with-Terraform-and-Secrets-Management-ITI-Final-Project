# Quick Deploy Guide

## One-Command Deployment

Deploy everything (infrastructure + Jenkins) in one go:

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

Wait ~15-20 minutes ☕

## Post-Deployment (3 commands)

```bash
# 1. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster

# 2. Verify Jenkins is running
kubectl get pods -n jenkins

# 3. Access Jenkins
kubectl --namespace jenkins port-forward svc/jenkins 8080:8080
```

Open: http://localhost:8080

## Get Admin Password

```bash
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password
```

## Verify Everything

```bash
# Check all resources
kubectl get all -n jenkins

# Check ECR repository
aws ecr describe-repositories --repository-names nodejs-app --region us-east-1

# Check RDS
aws rds describe-db-instances --region us-east-1

# Check Redis
aws elasticache describe-cache-clusters --region us-east-1
```

## Destroy Everything

```bash
cd terraform
terraform destroy -auto-approve
```

## That's It!

Everything is automated:
- ✅ VPC, EKS, RDS, Redis, ECR
- ✅ Jenkins with all plugins
- ✅ IAM roles and IRSA
- ✅ Kubernetes resources
- ✅ Ready to use!

Next: Create Jenkins pipeline (see `jenkins/QUICK_START.md`)
