# AWS GitOps Pipeline - CI/CD with Jenkins, ArgoCD & Helm

Production-ready GitOps pipeline: Terraform → Jenkins → ECR → ArgoCD Image Updater → ArgoCD → EKS

**Result:** Push code → Auto-deploy in ~5 minutes

---

## 🎯 What's Included

- Terraform (VPC, EKS, RDS, Redis, ECR, IAM)
- Jenkins CI (build & push to ECR)
- ArgoCD CD (GitOps deployment)
- ArgoCD Image Updater (auto-detect new images)
- External Secrets Operator (AWS Secrets Manager)
- AWS Load Balancer Controller (ALB Ingress)
- Modern web UI (task manager with RDS + Redis)

---

## 🚀 Quick Start (30 minutes)

### Prerequisites
- AWS CLI configured
- kubectl, Helm 3, Terraform installed

### Step 1: Deploy Infrastructure (15 min)

PowerShell:
```powershell
cd terraform
terraform init
terraform apply -var="db_password=YourSecurePassword123!" -auto-approve
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
kubectl get nodes
```

Linux/Mac:
```bash
cd terraform
terraform init
terraform apply -var="db_password=YourSecurePassword123!" -auto-approve
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
kubectl get nodes
```

### Step 2: Install Jenkins (3 min)

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins --namespace jenkins --create-namespace --values terraform/jenkins-helm-values.yaml
```

Annotate Jenkins service account with IAM role (for ECR access):

PowerShell:
```powershell
cd terraform; $ROLE_ARN = terraform output -raw jenkins_role_arn; cd ..
kubectl annotate serviceaccount jenkins -n jenkins eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
kubectl delete pod jenkins-0 -n jenkins  # Restart to apply IAM role
```

Linux/Mac:
```bash
ROLE_ARN=$(cd terraform && terraform output -raw jenkins_role_arn)
kubectl annotate serviceaccount jenkins -n jenkins eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
kubectl delete pod jenkins-0 -n jenkins  # Restart to apply IAM role
```

Access Jenkins:
```bash
# Get admin password
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password

# Port forward (run in separate terminal)
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
```
Open http://localhost:8080 (admin / password-from-above)

Create pipeline: New Item → `nodejs-app-git-pipeline` → Pipeline → SCM: Git → Repo: `https://github.com/Ahmed-Maher-Sabeq/Full-GitOps-Pipeline-on-AWS-with-Terraform-and-Secrets-Management-ITI-Final-Project.git` → Branch: `*/main` → Script Path: `nodejs-app/Jenkinsfile` → Save → Build Now

### Step 3: Install ArgoCD (3 min)

```bash
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --set server.service.type=ClusterIP
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

Get ArgoCD admin password:

PowerShell:
```powershell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

Linux/Mac:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Port forward (run in separate terminal):
```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```
Open https://localhost:8081 (admin / password-from-above)

### Step 4: Install ArgoCD Image Updater (2 min)

```bash
helm install argocd-image-updater argo/argocd-image-updater --namespace argocd --set config.argocd.insecure=true --set config.argocd.plaintext=true
```

Create ECR credentials secret (for Image Updater to access ECR):

PowerShell:
```powershell
$ECR_PASSWORD = aws ecr get-login-password --region us-east-1
kubectl create secret docker-registry ecr-credentials --docker-server=287043460305.dkr.ecr.us-east-1.amazonaws.com --docker-username=AWS --docker-password=$ECR_PASSWORD -n argocd --dry-run=client -o yaml | kubectl apply -f -
```

Linux/Mac:
```bash
aws ecr get-login-password --region us-east-1 | kubectl create secret docker-registry ecr-credentials --docker-server=287043460305.dkr.ecr.us-east-1.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password --region us-east-1) -n argocd --dry-run=client -o yaml | kubectl apply -f -
```

### Step 5: Install External Secrets Operator (2 min)

```bash
kubectl create namespace external-secrets-system
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets --namespace external-secrets-system
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets-system --timeout=300s
```

### Step 6: Deploy Application (2 min)

```bash
kubectl apply -f k8s/argocd/application.yaml  # Create ArgoCD application
kubectl get application nodejs-app -n argocd -w  # Watch deployment status
```
Wait for STATUS: Synced, HEALTH: Healthy. Press Ctrl+C.

Verify:
```bash
kubectl get pods -n nodejs-app
kubectl get externalsecret -n nodejs-app
kubectl get secretstore -n nodejs-app
```

### Step 7: Install AWS Load Balancer Controller (3 min)

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=gitops-eks-cluster --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller
```

Annotate service account with IAM role (for ALB management):

PowerShell:
```powershell
cd terraform; $ROLE_ARN = terraform output -raw aws_lb_controller_role_arn; cd ..
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system  # Restart to apply IAM role
```

Linux/Mac:
```bash
ROLE_ARN=$(cd terraform && terraform output -raw aws_lb_controller_role_arn)
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system  # Restart to apply IAM role
```

Wait for ALB creation (2-3 min):
```bash
kubectl get ingress -n nodejs-app -w  # Watch for ADDRESS field
```
Wait for ADDRESS. Press Ctrl+C.

Get ALB URL and test:

PowerShell:
```powershell
$ALB_URL = kubectl get ingress nodejs-app -n nodejs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Application URL: http://$ALB_URL"
curl "http://$ALB_URL/health"  # Test health endpoint
```

Linux/Mac:
```bash
ALB_URL=$(kubectl get ingress nodejs-app -n nodejs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$ALB_URL"
curl "http://$ALB_URL/health"  # Test health endpoint
```

---

## 🧪 Test the Application

**Access Web UI:**
```bash
kubectl port-forward -n nodejs-app svc/nodejs-app 8082:80
```
Open http://localhost:8082

**Test API:**
```bash
curl http://localhost:8082/health
curl http://localhost:8082/api/items
curl -X POST http://localhost:8082/api/items -H "Content-Type: application/json" -d '{"name":"Test","description":"Demo"}'
```

**Test Pipeline:**
```bash
# Edit nodejs-app/src/routes/health.js
git add nodejs-app/src/routes/health.js
git commit -m "Test pipeline"
git push
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f  # Watch Image Updater detect new image
```

**Test Data Persistence:**
```bash
kubectl delete pod -n nodejs-app --all  # Delete all pods
kubectl get pods -n nodejs-app -w  # Watch new pods start
# Refresh web UI - data still there (stored in RDS, not in pods)
```

---

## 🐛 Troubleshooting

**Jenkins ECR 403:**
PowerShell:
```powershell
cd terraform; $ROLE_ARN = terraform output -raw jenkins_role_arn; cd ..
kubectl annotate serviceaccount jenkins -n jenkins eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
kubectl delete pod jenkins-0 -n jenkins
```

Linux/Mac:
```bash
ROLE_ARN=$(cd terraform && terraform output -raw jenkins_role_arn)
kubectl annotate serviceaccount jenkins -n jenkins eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
kubectl delete pod jenkins-0 -n jenkins
```

**Pods Stuck (Missing Secrets):**
```bash
cd terraform
terraform apply -var="db_password=YourPassword" -auto-approve
kubectl delete pod -n nodejs-app --all
```

**Image Updater Not Working:**
PowerShell:
```powershell
$ECR_PASSWORD = aws ecr get-login-password --region us-east-1
kubectl create secret docker-registry ecr-credentials --docker-server=287043460305.dkr.ecr.us-east-1.amazonaws.com --docker-username=AWS --docker-password=$ECR_PASSWORD -n argocd --dry-run=client -o yaml | kubectl apply -f -
```

Linux/Mac:
```bash
aws ecr get-login-password --region us-east-1 | kubectl create secret docker-registry ecr-credentials --docker-server=287043460305.dkr.ecr.us-east-1.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password --region us-east-1) -n argocd --dry-run=client -o yaml | kubectl apply -f -
```

---

## 🔒 Optional: Add HTTPS

### Option 1: CloudFront (No Domain Needed)

Add to `terraform/main.tf`:
```hcl
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = "YOUR_ALB_DNS"
    origin_id   = "alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled = true
  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = true
      headers      = ["Host"]
      cookies { forward = "all" }
    }
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions {
    geo_restriction { restriction_type = "none" }
  }
}
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.main.domain_name
}
```

```bash
cd terraform
terraform apply -var="db_password=YourPassword" -auto-approve
terraform output -raw cloudfront_domain
```

### Option 2: ACM Certificate (Requires Domain)

```bash
aws acm request-certificate --domain-name myapp.com --validation-method DNS --region us-east-1
```

Edit `k8s/helm-chart/nodejs-app/values.yaml`:
```yaml
ingress:
  certificateArn: "arn:aws:acm:us-east-1:123456789:certificate/abc-123"
```

```bash
git add k8s/helm-chart/nodejs-app/values.yaml
git commit -m "Add HTTPS"
git push
```

---

## 🗑️ Cleanup

**⚠️ Follow this order to avoid stuck VPC deletion!**

```bash
# 1. Delete ArgoCD app
kubectl delete application nodejs-app -n argocd
kubectl wait --for=delete ingress/nodejs-app -n nodejs-app --timeout=300s
```

**If Ingress stuck:**
PowerShell:
```powershell
kubectl patch ingress nodejs-app -n nodejs-app -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge
kubectl delete ingress nodejs-app -n nodejs-app --force --grace-period=0
```

Linux/Mac:
```bash
kubectl patch ingress nodejs-app -n nodejs-app -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl delete ingress nodejs-app -n nodejs-app --force --grace-period=0
```

**Delete ALB & Target Groups (created by LB Controller):**

PowerShell:
```powershell
$ALB_ARN = aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`)].LoadBalancerArn' --output text
if ($ALB_ARN) { aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN }
$TG_ARN = aws elbv2 describe-target-groups --region us-east-1 --query 'TargetGroups[?contains(TargetGroupName, `k8s-`)].TargetGroupArn' --output text
if ($TG_ARN) { aws elbv2 delete-target-group --target-group-arn $TG_ARN }
Start-Sleep -Seconds 30  # Wait for ALB deletion
```

Linux/Mac:
```bash
aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`)].LoadBalancerArn' --output text | xargs -I {} aws elbv2 delete-load-balancer --load-balancer-arn {}
aws elbv2 describe-target-groups --region us-east-1 --query 'TargetGroups[?contains(TargetGroupName, `k8s-`)].TargetGroupArn' --output text | xargs -I {} aws elbv2 delete-target-group --target-group-arn {}
sleep 30  # Wait for ALB deletion
```

**Delete Security Groups (created by LB Controller):**

PowerShell:
```powershell
cd terraform; $VPC_ID = terraform output -raw vpc_id; cd ..
$SGs = aws ec2 describe-security-groups --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?contains(GroupName, `k8s-`)].GroupId' --output text
if ($SGs) { $SGs -split "`t" | ForEach-Object { aws ec2 delete-security-group --group-id $_ } }
```

Linux/Mac:
```bash
VPC_ID=$(cd terraform && terraform output -raw vpc_id)
aws ec2 describe-security-groups --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?contains(GroupName, `k8s-`)].GroupId' --output text | xargs -I {} aws ec2 delete-security-group --group-id {}
```

**Uninstall Helm & Destroy:**
```bash
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall jenkins -n jenkins
helm uninstall argocd -n argocd
helm uninstall argocd-image-updater -n argocd
helm uninstall external-secrets -n external-secrets-system
cd terraform
terraform destroy -var="db_password=YourPassword" -auto-approve
```

**Why this order?** AWS LB Controller creates ALB, target groups, and security groups outside Terraform. Deleting them first prevents VPC from hanging for 15+ minutes.

---

## 🔗 Quick Commands

```bash
# Check status
kubectl get pods --all-namespaces
kubectl get application -n argocd
kubectl get ingress -n nodejs-app

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=20
kubectl logs -n nodejs-app -l app=nodejs-app --tail=20

# Current image
kubectl get deployment nodejs-app -n nodejs-app -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## 💰 Cost: ~$213/month | Destroy: $0

- EKS: $73 | EC2: $60 | RDS: $15 | Redis: $12 | ALB: $16 | NAT: $32 | Data: $5

---

## 📁 Project Structure

```
├── terraform/          # IaC (VPC, EKS, RDS, Redis, ECR, IAM)
├── k8s/
│   ├── helm-chart/     # Helm chart
│   └── argocd/         # ArgoCD app
└── nodejs-app/         # Node.js app (Express + MySQL + Redis)
```

---

## 🔄 Pipeline Flow

```
Push → Jenkins → ECR → Image Updater → ArgoCD → EKS → Running!
```

---

**Last Updated:** November 11, 2025  
**Status:** ✅ Complete GitOps pipeline with ALB Ingress
