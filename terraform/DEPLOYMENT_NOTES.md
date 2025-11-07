# Terraform Deployment Notes

## Prerequisites
1. AWS CLI configured with credentials (already done via creds file)
2. Terraform installed (version >= 1.0)
3. kubectl installed for EKS cluster access

## Before Deployment

### Set Database Password
You must set the database password before running terraform apply. You can do this in one of two ways:

**Option 1: Environment Variable (Recommended)**
```bash
export TF_VAR_db_password="YourSecurePassword123!"
```

**Option 2: Add to terraform.tfvars**
Add this line to `terraform.tfvars`:
```
db_password = "YourSecurePassword123!"
```

## Deployment Steps

### 1. Initialize Terraform
```bash
cd terraform
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Apply the Configuration
```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 4. Save Outputs
After successful deployment, save the outputs:
```bash
terraform output > outputs.txt
```

### 5. Configure kubectl
Use the command from terraform outputs:
```bash
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
```

### 6. Verify EKS Cluster
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Testing Infrastructure

### Test VPC and Subnets
```bash
# List VPCs
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=aws-gitops-pipeline"

# List Subnets
aws ec2 describe-subnets --filters "Name=tag:Project,Values=aws-gitops-pipeline"
```

### Test EKS Cluster
```bash
# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes -o wide

# Check node status
kubectl describe nodes
```

### Test RDS Connectivity
Create a test pod to verify RDS connectivity:
```bash
kubectl run mysql-test --image=mysql:8.0 --rm -it --restart=Never -- mysql -h <RDS_ENDPOINT> -u admin -p
```

### Test ElastiCache Connectivity
Create a test pod to verify Redis connectivity:
```bash
kubectl run redis-test --image=redis:7.0 --rm -it --restart=Never -- redis-cli -h <REDIS_ENDPOINT> ping
```

### Test ECR Repository
```bash
# List ECR repositories
aws ecr describe-repositories --repository-names nodejs-app

# Get login command
aws ecr get-login-password --region us-east-1
```

## Important Outputs

After deployment, note these important values:
- **EKS Cluster Endpoint**: For kubectl configuration
- **RDS Endpoint**: For application database connection
- **Redis Endpoint**: For application cache connection
- **ECR Repository URL**: For pushing Docker images
- **OIDC Provider ARN**: For IAM Roles for Service Accounts (IRSA)
- **RDS Secret ARN**: For External Secrets Operator
- **Redis Secret ARN**: For External Secrets Operator

## Cleanup (When Done)

To destroy all resources:
```bash
terraform destroy
```

Type `yes` when prompted to confirm.

**Note**: This will delete all resources including databases. Make sure to backup any important data first.

## Troubleshooting

### Issue: Terraform init fails
- Check internet connectivity
- Verify AWS credentials are correct

### Issue: EKS cluster creation fails
- Check AWS service quotas for EKS
- Verify IAM permissions

### Issue: RDS creation fails
- Check if you have enough RDS instances in your quota
- Verify subnet group has subnets in multiple AZs

### Issue: Cannot connect to EKS cluster
- Run: `aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster`
- Verify AWS credentials have EKS permissions

## Estimated Deployment Time
- VPC: ~2 minutes
- EKS Cluster: ~10-15 minutes
- RDS Instance: ~5-10 minutes
- ElastiCache: ~5-10 minutes
- ECR: ~1 minute

**Total: Approximately 25-40 minutes**
