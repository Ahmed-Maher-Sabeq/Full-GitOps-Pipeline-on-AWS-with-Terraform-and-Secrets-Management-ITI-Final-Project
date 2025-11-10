# AWS GitOps Pipeline - Complete CI/CD with Jenkins, ArgoCD & Helm

Production-ready GitOps pipeline with automated image updates and secrets management.

---

## 🎯 What We Built

**Complete CI/CD Pipeline:**
- Terraform → AWS Infrastructure (VPC, EKS, RDS, Redis, ECR)
- Jenkins → Build & Push to ECR
- ArgoCD Image Updater → Auto-detect new images
- ArgoCD → Deploy Helm charts
- External Secrets Operator → Sync from AWS Secrets Manager

**Result:** Push code → Auto-deploy to production in ~5 minutes

---

## � Quick eStart (30 minutes)

### Prerequisites
- AWS CLI configured
- kubectl, Helm 3, Terraform installed
- This repo cloned

### Step 1: Deploy Infrastructure (15 min)

**PowerShell:**
```powershell
cd terraform
terraform init
terraform apply -var="db_password=YourSecurePassword123!" -auto-approve

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
kubectl get nodes  # Verify 2-3 nodes ready
```

**Linux/Mac:**
```bash
cd terraform
terraform init
terraform apply -var="db_password=YourSecurePassword123!" -auto-approve

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
kubectl get nodes  # Verify 2-3 nodes ready
```

**Creates:** VPC, EKS, RDS, Redis, ECR, IAM roles (including nodejs-app-secrets-role), Secrets in AWS Secrets Manager

### Step 2: Install Jenkins (3 min)

**Both PowerShell & Linux/Mac:**
```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values terraform/jenkins-helm-values.yaml
```

**Annotate service account with IAM role:**

PowerShell:
```powershell
cd terraform
$ROLE_ARN = terraform output -raw jenkins_role_arn
cd ..
kubectl annotate serviceaccount jenkins -n jenkins `
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
```

Linux/Mac:
```bash
ROLE_ARN=$(cd terraform && terraform output -raw jenkins_role_arn)
kubectl annotate serviceaccount jenkins -n jenkins \
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
```

**Restart Jenkins (both platforms):**
```bash
kubectl delete pod jenkins-0 -n jenkins
kubectl wait --for=condition=ready pod/jenkins-0 -n jenkins --timeout=300s
```

**Access Jenkins:**
```bash
# Get password
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password

# Port forward (separate terminal)
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
```

**URL:** http://localhost:8080 (admin / password-from-above)

### Step 3: Create Jenkins Pipeline (2 min)

1. Jenkins UI → **New Item** → `nodejs-app-git-pipeline` → **Pipeline**
2. **Definition:** Pipeline script from SCM
3. **SCM:** Git
4. **Repository:** `https://github.com/Ahmed-Maher-Sabeq/Full-GitOps-Pipeline-on-AWS-with-Terraform-and-Secrets-Management-ITI-Final-Project.git`
5. **Branch:** `*/main`
6. **Script Path:** `nodejs-app/Jenkinsfile`
7. **Save** → **Build Now**

**Verify image in ECR (both platforms):**
```bash
aws ecr describe-images --repository-name nodejs-app --region us-east-1
```

### Step 4: Install ArgoCD (3 min)

**Both PowerShell & Linux/Mac:**
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

**Get ArgoCD password:**

PowerShell:
```powershell
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | ForEach-Object { `
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

Linux/Mac:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**Port forward (both platforms, separate terminal):**
```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

**URL:** https://localhost:8081 (admin / password-from-above)

### Step 5: Install ArgoCD Image Updater (2 min)

**Both PowerShell & Linux/Mac:**
```bash
helm install argocd-image-updater argo/argocd-image-updater \
  --namespace argocd \
  --set config.argocd.insecure=true \
  --set config.argocd.plaintext=true
```

**Create ECR credentials secret:**

PowerShell:
```powershell
$ECR_PASSWORD = aws ecr get-login-password --region us-east-1
kubectl create secret docker-registry ecr-credentials `
  --docker-server=287043460305.dkr.ecr.us-east-1.amazonaws.com `
  --docker-username=AWS `
  --docker-password=$ECR_PASSWORD `
  -n argocd `
  --dry-run=client -o yaml | kubectl apply -f -
```

Linux/Mac:
```bash
aws ecr get-login-password --region us-east-1 | \
kubectl create secret docker-registry ecr-credentials \
  --docker-server=287043460305.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 6: Install External Secrets Operator (2 min)

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

### Step 7: Deploy Application (2 min)

```bash
kubectl apply -f k8s/argocd/application.yaml

# Watch deployment
kubectl get application nodejs-app -n argocd -w
```

Wait for STATUS: Synced, HEALTH: Healthy (2-3 min). Press Ctrl+C when ready.

**Verify:**
```bash
kubectl get pods -n nodejs-app              # Should show 3 running pods
kubectl get externalsecret -n nodejs-app    # Should show Ready: True
kubectl get secretstore -n nodejs-app       # Should show Ready: True
```

### Step 8: Install AWS Load Balancer Controller (3 min)

**Both PowerShell & Linux/Mac:**
```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=gitops-eks-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller
```

**Annotate service account with IAM role:**

PowerShell:
```powershell
cd terraform
$ROLE_ARN = terraform output -raw aws_lb_controller_role_arn
cd ..
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system `
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
```

Linux/Mac:
```bash
ROLE_ARN=$(cd terraform && terraform output -raw aws_lb_controller_role_arn)
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
```

**Restart controller (both platforms):**
```bash
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  -n kube-system --timeout=300s
```

**Verify ALB created:**
```bash
# Wait for Ingress to get an address (2-3 min)
kubectl get ingress -n nodejs-app -w
```

Press Ctrl+C when you see an ADDRESS like: `k8s-nodejsap-nodejsap-xxxxx.us-east-1.elb.amazonaws.com`

**Get ALB URL:**

PowerShell:
```powershell
$ALB_URL = kubectl get ingress nodejs-app -n nodejs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Application URL: http://$ALB_URL"
```

Linux/Mac:
```bash
ALB_URL=$(kubectl get ingress nodejs-app -n nodejs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$ALB_URL"
```

**Test the application:**
```bash
curl http://$ALB_URL/health
```

Open the ALB URL in your browser to access the web UI!

---

## 🎉 Test the Pipeline

### Make a code change:
```bash
# Edit nodejs-app/src/routes/health.js - add version field
git add nodejs-app/src/routes/health.js
git commit -m "Test pipeline"
git push
```

### Watch the magic:
```bash
# 1. Jenkins builds (2-3 min)
# 2. Image Updater detects new image (within 2 min)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f

# 3. Pods roll out with new version
kubectl get pods -n nodejs-app -w
```

**Total time:** ~5-7 minutes from push to production!

---

## 🧪 Test the Application

### Access the Web UI

**Port forward the service:**
```bash
kubectl port-forward -n nodejs-app svc/nodejs-app 8082:80
```

**Open in browser:** http://localhost:8082

### Web Interface Features

The application includes a modern task manager GUI with:

- 📊 **Real-time Status Dashboard**
  - Total tasks count
  - MySQL (RDS) connection status
  - Redis cache connection status
  - Application version

- ✨ **Task Management**
  - ➕ Create new tasks with name and description
  - ✏️ Edit existing tasks inline
  - 🗑️ Delete tasks with confirmation
  - 🔄 Refresh to reload tasks

- 🎨 **Modern UI**
  - Responsive design (mobile-friendly)
  - Gradient purple theme
  - Toast notifications for actions
  - Smooth animations

### Test API Endpoints (CLI)

**Health check:**
```bash
curl http://localhost:8082/health
```

**List all tasks:**
```bash
curl http://localhost:8082/api/items
```

**Create a task:**
```bash
curl -X POST http://localhost:8082/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Deploy to production","description":"Test the GitOps pipeline"}'
```

**Get specific task (replace 1 with actual ID):**
```bash
curl http://localhost:8082/api/items/1
```

**Update a task:**
```bash
curl -X PUT http://localhost:8082/api/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated task","description":"Modified via API"}'
```

**Delete a task:**
```bash
curl -X DELETE http://localhost:8082/api/items/1
```

### Test Data Persistence

**Verify RDS persistence:**
```bash
# 1. Create some tasks via the web UI
# 2. Delete all pods
kubectl delete pod -n nodejs-app --all

# 3. Wait for new pods to start
kubectl get pods -n nodejs-app -w

# 4. Refresh the web UI - all tasks still there! ✅
```

**Why?** Tasks are stored in RDS (MySQL), not in pods. Pods are stateless.

### Test Redis Caching

**First request (Cache MISS):**
```bash
# Check pod logs while making request
kubectl logs -n nodejs-app -l app=nodejs-app --tail=5 -f &
curl http://localhost:8082/api/items
```
Look for: `❌ Cache MISS for key: items:all`

**Second request (Cache HIT):**
```bash
curl http://localhost:8082/api/items
```
Look for: `✅ Cache HIT for key: items:all` (faster response!)

**Cache invalidation test:**
```bash
# 1. List tasks (cached)
curl http://localhost:8082/api/items

# 2. Create new task (invalidates cache)
curl -X POST http://localhost:8082/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test cache","description":"This will clear the cache"}'

# 3. List tasks again (cache miss, then cached again)
curl http://localhost:8082/api/items
```

### Test Secrets Management

**Verify secrets are injected from AWS Secrets Manager:**
```bash
# Check ExternalSecret status
kubectl get externalsecret -n nodejs-app

# Check that secrets exist
kubectl get secret rds-secret -n nodejs-app
kubectl get secret redis-secret -n nodejs-app

# Verify app can connect to RDS and Redis
curl http://localhost:8082/health
```

Expected output:
```json
{
  "status": "healthy",
  "version": "v2.0-testing-image-updater",
  "timestamp": "2025-11-10T...",
  "services": {
    "mysql": "connected",
    "redis": "connected"
  }
}
```

### Test High Availability

**With 3 replicas running:**
```bash
# Delete one pod
kubectl delete pod -n nodejs-app $(kubectl get pods -n nodejs-app -o jsonpath='{.items[0].metadata.name}')

# App still works! Try the web UI or:
curl http://localhost:8082/health
```

**Scale test:**
```bash
# Scale down to 1 replica
kubectl scale deployment nodejs-app -n nodejs-app --replicas=1

# Still works!
curl http://localhost:8082/api/items

# Scale back up
kubectl scale deployment nodejs-app -n nodejs-app --replicas=3
```

---

## 🐛 Critical Fixes

### Problem 1: Jenkins ECR 403 Error

**Symptom:** Pipeline fails with "not authorized to perform: ecr:InitiateLayerUpload"

**Fix:**

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

### Problem 2: Pods Stuck in CreateContainerConfigError

**Symptom:** Pods can't start, secrets missing

**Root Cause:** IAM role for nodejs-app service account wasn't created initially

**Fix:** The IAM role `nodejs-app-secrets-role` is now created by Terraform in `terraform/modules/eks/main.tf`. If you deployed before this fix:

```bash
# Re-run Terraform to create the IAM role
cd terraform
terraform apply -var="db_password=YourPassword" -auto-approve

# Restart pods to pick up the role
kubectl delete pod -n nodejs-app --all
```

**Verify the fix:**
```bash
# Check IAM role exists
aws iam get-role --role-name nodejs-app-secrets-role

# Check service account has annotation
kubectl get sa nodejs-app-sa -n nodejs-app -o yaml | grep eks.amazonaws.com/role-arn

# Check SecretStore is ready
kubectl get secretstore aws-secrets-manager -n nodejs-app
```

### Problem 3: ExternalSecret Shows Wrong Secret Name

**Symptom:** ExternalSecret can't find secret in AWS Secrets Manager

**Fix:** Update `k8s/helm-chart/nodejs-app/values.yaml`:
```yaml
secrets:
  rds:
    remoteRef: aws-gitops-pipeline-dev-rds-credentials  # Full name from AWS
  redis:
    remoteRef: aws-gitops-pipeline-dev-redis-credentials
```

Then commit and push - ArgoCD will auto-sync.

### Problem 4: Image Updater Not Working

**Symptom:** New images not detected

**Fix:** Ensure ECR credentials secret exists:

PowerShell:
```powershell
$ECR_PASSWORD = aws ecr get-login-password --region us-east-1
kubectl create secret docker-registry ecr-credentials `
  --docker-server=287043460305.dkr.ecr.us-east-1.amazonaws.com `
  --docker-username=AWS `
  --docker-password=$ECR_PASSWORD `
  -n argocd `
  --dry-run=client -o yaml | kubectl apply -f -
```

Linux/Mac:
```bash
aws ecr get-login-password --region us-east-1 | \
kubectl create secret docker-registry ecr-credentials \
  --docker-server=287043460305.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 📁 Project Structure

```
├── terraform/                    # Infrastructure as Code
│   ├── modules/                  # VPC, EKS, RDS, Redis, ECR
│   ├── main.tf                   # Root + IAM roles (including nodejs-app-secrets-role)
│   └── jenkins-helm-values.yaml
│
├── k8s/
│   ├── helm-chart/nodejs-app/    # Helm chart for application
│   │   ├── values.yaml           # Config (image, replicas, secrets)
│   │   └── templates/            # K8s manifests
│   └── argocd/
│       └── application.yaml      # ArgoCD app with Image Updater annotations
│
└── nodejs-app/                   # Node.js app
    ├── src/                      # Express + MySQL + Redis
    ├── Dockerfile
    └── Jenkinsfile               # CI pipeline (Kaniko)
```

---

## 🔄 Complete Flow

```
1. Push code to GitHub
2. Jenkins builds Docker image (Kaniko)
3. Push to ECR with build-X tag
4. Image Updater detects new image (every 2 min)
5. Updates ArgoCD Application spec
6. ArgoCD syncs Helm chart
7. ESO creates secrets from AWS Secrets Manager
8. Pods roll out with new version
9. Application running!
```

---

## 🔒 Optional: Add HTTPS Support

Currently, the application is accessible via HTTP through the ALB. Here are your options to add HTTPS:

### Option 1: CloudFront + ALB (No Domain Needed) ⭐ Recommended

**Benefits:**
- ✅ Free HTTPS with AWS-provided domain (`*.cloudfront.net`)
- ✅ No domain purchase required
- ✅ CDN benefits (caching, global performance)
- ✅ DDoS protection (AWS Shield)
- ✅ No browser warnings

**Architecture:**
```
Internet → CloudFront (HTTPS) → ALB (HTTP) → Pods
           d1234abcd.cloudfront.net
```

**Implementation Steps:**

1. **Create CloudFront distribution via Terraform:**

Add to `terraform/main.tf`:
```hcl
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = module.eks.alb_dns_name  # Your ALB DNS
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
    
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]
    
    forwarded_values {
      query_string = true
      headers      = ["Host"]
      cookies {
        forward = "all"
      }
    }
    
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-cloudfront"
  }
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.main.domain_name
}
```

2. **Apply Terraform:**
```bash
cd terraform
terraform apply -var="db_password=YourPassword" -auto-approve
```

3. **Get CloudFront URL:**

PowerShell:
```powershell
cd terraform
$CF_URL = terraform output -raw cloudfront_domain
Write-Host "HTTPS URL: https://$CF_URL"
```

Linux/Mac:
```bash
CF_URL=$(cd terraform && terraform output -raw cloudfront_domain)
echo "HTTPS URL: https://$CF_URL"
```

4. **Access your app with HTTPS:**
```
https://d1234abcd.cloudfront.net
```

**Cost:** ~$0-1/month (Free tier: 1TB data transfer, then $0.085/GB)

---

### Option 2: ACM Certificate with Your Domain

**Requirements:**
- Own a domain name (e.g., `myapp.com`)

**Benefits:**
- ✅ Branded domain
- ✅ Professional appearance
- ✅ Free SSL certificate from ACM

**Implementation Steps:**

1. **Request ACM certificate:**
```bash
aws acm request-certificate \
  --domain-name myapp.com \
  --validation-method DNS \
  --region us-east-1
```

2. **Validate domain ownership:**
- Add DNS records shown in ACM console
- Wait for validation (5-30 minutes)

3. **Update Ingress with certificate ARN:**

Edit `k8s/helm-chart/nodejs-app/values.yaml`:
```yaml
ingress:
  enabled: true
  scheme: internet-facing
  targetType: ip
  certificateArn: "arn:aws:acm:us-east-1:123456789:certificate/abc-123"
```

4. **Commit and push:**
```bash
git add k8s/helm-chart/nodejs-app/values.yaml
git commit -m "Add HTTPS with ACM certificate"
git push
```

5. **Create Route 53 record:**
```bash
# Get ALB DNS
ALB_DNS=$(kubectl get ingress nodejs-app -n nodejs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create A record (ALIAS) in Route 53 pointing myapp.com to $ALB_DNS
```

6. **Access your app:**
```
https://myapp.com
```

**Cost:** ~$0.50/month (Route 53 hosted zone) + domain cost (~$10-15/year)

---

### Option 3: Self-Signed Certificate (Not Recommended)

**Only for testing/development:**
- ⚠️ Browser shows security warnings
- ⚠️ Not suitable for production
- ⚠️ Users must manually accept certificate

---

## 📋 What's Remaining (Optional Enhancements)

The core GitOps pipeline is complete! Optional improvements:

### Completed ✅
- ✅ Infrastructure (VPC, EKS, RDS, Redis, ECR)
- ✅ Jenkins CI pipeline with ECR push
- ✅ ArgoCD CD with GitOps
- ✅ ArgoCD Image Updater (auto-deployment)
- ✅ External Secrets Operator (AWS Secrets Manager)
- ✅ AWS Load Balancer Controller (ALB Ingress)
- ✅ Modern web UI with task management
- ✅ Full documentation

### Optional Enhancements 🚀
- [ ] **HTTPS Support** - Add CloudFront or ACM certificate (see above)
- [ ] **Monitoring** - Prometheus + Grafana for metrics
- [ ] **Logging** - ELK Stack or CloudWatch Logs
- [ ] **Alerting** - AlertManager or SNS notifications
- [ ] **Backup** - Velero for cluster backups
- [ ] **Cost Optimization** - Spot instances, autoscaling
- [ ] **Security Scanning** - Trivy for container scanning
- [ ] **Multi-Environment** - Dev, Staging, Production
- [ ] **Custom Domain** - Route 53 + ACM certificate
- [ ] **WAF** - AWS WAF for security rules

---

## 🗑️ Cleanup

**⚠️ IMPORTANT: Follow this order to avoid stuck resources!**

The AWS Load Balancer Controller creates security groups and ALBs that aren't managed by Terraform. You must delete them in the correct order.

### Proper Cleanup Order

**Step 1: Delete ArgoCD Application (removes Ingress)**
```bash
kubectl delete application nodejs-app -n argocd
```

**Step 2: Wait for Ingress deletion**
```bash
kubectl wait --for=delete ingress/nodejs-app -n nodejs-app --timeout=300s
```

**Step 3: If Ingress is stuck, force delete it**

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

**Step 4: Manually delete ALB and target groups (if still exist)**

PowerShell:
```powershell
# Delete ALBs
$ALB_ARN = aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`)].LoadBalancerArn' --output text
if ($ALB_ARN) { aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN }

# Delete target groups
$TG_ARN = aws elbv2 describe-target-groups --region us-east-1 --query 'TargetGroups[?contains(TargetGroupName, `k8s-`)].TargetGroupArn' --output text
if ($TG_ARN) { aws elbv2 delete-target-group --target-group-arn $TG_ARN }
```

Linux/Mac:
```bash
# Delete ALBs
aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`)].LoadBalancerArn' --output text | \
  xargs -I {} aws elbv2 delete-load-balancer --load-balancer-arn {}

# Delete target groups
aws elbv2 describe-target-groups --region us-east-1 --query 'TargetGroups[?contains(TargetGroupName, `k8s-`)].TargetGroupArn' --output text | \
  xargs -I {} aws elbv2 delete-target-group --target-group-arn {}
```

**Step 5: Wait for ALB deletion (30 seconds)**
```bash
# Both platforms
Start-Sleep -Seconds 30  # PowerShell
sleep 30                 # Linux/Mac
```

**Step 6: Delete security groups created by AWS LB Controller**

PowerShell:
```powershell
cd terraform
$VPC_ID = terraform output -raw vpc_id
cd ..
$SGs = aws ec2 describe-security-groups --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?contains(GroupName, `k8s-`)].GroupId' --output text
if ($SGs) {
    $SGs -split "`t" | ForEach-Object { aws ec2 delete-security-group --group-id $_ }
}
```

Linux/Mac:
```bash
VPC_ID=$(cd terraform && terraform output -raw vpc_id)
aws ec2 describe-security-groups --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[?contains(GroupName, `k8s-`)].GroupId' --output text | \
  xargs -I {} aws ec2 delete-security-group --group-id {}
```

**Step 7: Uninstall Helm releases**
```bash
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall jenkins -n jenkins
helm uninstall argocd -n argocd
helm uninstall argocd-image-updater -n argocd
helm uninstall external-secrets -n external-secrets-system
```

**Step 8: Finally, destroy Terraform infrastructure**
```bash
cd terraform
terraform destroy -var="db_password=YourPassword" -auto-approve
```

---

### Why This Order Matters

The AWS Load Balancer Controller creates resources outside Terraform:
- **ALB** - Application Load Balancer
- **Target Groups** - For routing traffic
- **Security Groups** - For ALB and EKS traffic

If you run `terraform destroy` first, the VPC deletion will hang for 15+ minutes waiting for these resources to be cleaned up. Following the proper order ensures a clean, fast deletion (~2-3 minutes).

---

## 🔗 Quick Commands

**Check everything:**
```bash
kubectl get pods --all-namespaces
kubectl get application -n argocd
kubectl get externalsecret -n nodejs-app
```

**Current image:**
```bash
kubectl get deployment nodejs-app -n nodejs-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Image Updater logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=20
```

**Test application:**
```bash
kubectl port-forward -n nodejs-app svc/nodejs-app 8082:80
curl http://localhost:8082/health
```

**Access via ALB:**
```bash
# Get ALB URL
kubectl get ingress nodejs-app -n nodejs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test
curl http://$(kubectl get ingress nodejs-app -n nodejs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/health
```

---

## 💰 Cost Estimate

**Monthly Costs:**
- EKS Cluster: ~$73/month ($0.10/hour)
- EC2 Nodes (2x t3.medium): ~$60/month
- RDS (db.t3.micro): ~$15/month
- ElastiCache (cache.t3.micro): ~$12/month
- ALB: ~$16/month
- NAT Gateway: ~$32/month
- Data Transfer: ~$5-10/month
- **Total: ~$213/month**

**Optional Additions:**
- CloudFront: ~$0-1/month (1TB free tier)
- Route 53 Hosted Zone: ~$0.50/month
- Domain: ~$10-15/year

**Destroy everything: $0** ✅

---

## 🔄 Restore After Destroy

If you destroy the infrastructure and want to restore it tomorrow:

1. **Deploy infrastructure:**
```bash
cd terraform
terraform apply -var="db_password=YourSecurePassword123!" -auto-approve
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
```

2. **Install all components (in order):**
```bash
# Jenkins (Step 2)
# ArgoCD (Step 4)
# ArgoCD Image Updater (Step 5)
# External Secrets Operator (Step 6)
# Deploy Application (Step 7)
# AWS Load Balancer Controller (Step 8)
```

3. **Verify everything:**
```bash
kubectl get pods --all-namespaces
kubectl get ingress -n nodejs-app
```

**Time to restore:** ~20-25 minutes

---

**Last Updated:** November 11, 2025  
**Status:** ✅ Complete GitOps pipeline with ALB Ingress working end-to-end
