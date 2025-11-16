# AWS GitOps Pipeline - Complete Architecture Explanation

This document provides a detailed explanation of every component in the GitOps pipeline project.

---

## Table of Contents

1. [Terraform Infrastructure](#terraform-infrastructure)
2. [Kubernetes Manifests](#kubernetes-manifests)
3. [Application Files](#application-files)

---

## Terraform Infrastructure

The Terraform configuration creates a complete AWS infrastructure for running a production-ready GitOps pipeline. The infrastructure is organized into modular components for maintainability and reusability.

### Core Terraform Files

#### 1. `terraform/provider.tf`

**Purpose:** Configures the Terraform AWS provider and sets up authentication.

**Key Components:**
- **Terraform Version:** Requires Terraform >= 1.0
- **AWS Provider:** Uses AWS provider version ~> 5.0
- **Region:** Deploys to `us-east-1`
- **Authentication:** Uses local credential files (`conf` and `creds`) for AWS authentication
- **Default Tags:** Automatically tags all resources with:
  - `Project`: Project name (aws-gitops-pipeline)
  - `Environment`: Environment name (dev)
  - `ManagedBy`: terraform

**Why this matters:** 
- Credential files allow the project to work with any AWS account without hardcoding account IDs
- Default tags help with cost tracking and resource management
- Version constraints ensure compatibility

---

#### 2. `terraform/variables.tf`

**Purpose:** Defines all configurable parameters for the infrastructure.

**Variable Categories:**

**Project Variables:**
- `project_name`: "aws-gitops-pipeline" - Used for naming resources
- `environment`: "dev" - Environment identifier

**VPC Variables:**
- `vpc_cidr`: "10.0.0.0/16" - Main network range
- `availability_zones`: 3 AZs for high availability
- `public_subnet_cidrs`: 3 public subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
- `private_subnet_cidrs`: 3 private subnets (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)

**EKS Variables:**
- `cluster_name`: "gitops-eks-cluster"
- `cluster_version`: "1.28" - Kubernetes version
- `node_instance_types`: ["t3.medium"] - EC2 instance type for worker nodes
- `node_desired_size`: 3 - Target number of nodes
- `node_min_size`: 1 - Minimum nodes for cost savings
- `node_max_size`: 4 - Maximum nodes for scaling

**RDS Variables:**
- `db_name`: "appdb" - Database name
- `db_username`: "admin" - Master username
- `db_password`: Sensitive variable (must be provided at runtime)
- `db_instance_class`: "db.t3.micro" - Small instance for cost efficiency
- `db_allocated_storage`: 20 GB
- `db_engine_version`: "8.0" - MySQL 8.0

**ElastiCache Variables:**
- `redis_cluster_id`: "gitops-redis"
- `redis_node_type`: "cache.t3.micro" - Small cache node
- `redis_num_cache_nodes`: 1 - Single node (no replication)
- `redis_engine_version`: "7.0" - Redis 7.0

**ECR Variables:**
- `ecr_repository_name`: "nodejs-app" - Container registry name

**Why this matters:**
- All values have sensible defaults for quick deployment
- Variables make the infrastructure reusable across environments
- Sensitive values (like passwords) are marked as sensitive

---

#### 3. `terraform/main.tf`

**Purpose:** Orchestrates all infrastructure modules and defines their dependencies.

**Module Flow:**

```
VPC → EKS → RDS/ElastiCache
         ↓
       ECR
         ↓
       IAM (IRSA roles)
```

**Module Breakdown:**

**1. VPC Module:**
- Creates the network foundation
- Provisions public and private subnets across 3 availability zones
- Sets up NAT gateways for private subnet internet access
- Tags subnets for EKS cluster discovery

**2. EKS Module:**
- Creates the Kubernetes cluster
- Provisions managed node groups
- Sets up OIDC provider for IRSA (IAM Roles for Service Accounts)
- Installs EBS CSI driver addon for persistent volumes
- Depends on VPC being created first

**3. RDS Module:**
- Creates MySQL database instance
- Places it in private subnets (not internet-accessible)
- Configures security groups to allow access only from EKS nodes
- Stores credentials in AWS Secrets Manager
- Depends on VPC and EKS

**4. ElastiCache Module:**
- Creates Redis cache cluster
- Places it in private subnets
- Configures security groups for EKS node access only
- Stores connection details in Secrets Manager
- Depends on VPC and EKS

**5. ECR Module:**
- Creates container registry for Docker images
- No dependencies (can be created independently)

**6. IAM Module:**
- Creates all IAM roles for IRSA (service account authentication)
- Depends on EKS (needs OIDC provider ARN)
- Depends on ECR (needs repository ARN for permissions)
- Depends on RDS and ElastiCache (needs secret ARNs)

**Why this matters:**
- Modular design makes code maintainable and testable
- Dependencies ensure resources are created in the correct order
- Each module is self-contained and reusable

---

#### 4. `terraform/outputs.tf`

**Purpose:** Exports important values for use by other tools and for reference.

**Output Categories:**

**VPC Outputs:**
- `vpc_id`: Used for security group configuration
- `public_subnet_ids`: For load balancers
- `private_subnet_ids`: For EKS nodes, RDS, Redis

**EKS Outputs:**
- `cluster_endpoint`: Kubernetes API server URL
- `cluster_name`: For kubectl configuration
- `oidc_provider_arn`: For creating IRSA roles
- `cluster_certificate_authority_data`: For kubectl authentication

**RDS Outputs:**
- `rds_endpoint`: Database connection string
- `rds_secret_arn`: Location of credentials in Secrets Manager

**ElastiCache Outputs:**
- `redis_endpoint`: Redis connection string
- `redis_secret_arn`: Location of connection details

**ECR Outputs:**
- `ecr_repository_url`: Full URL for pushing/pulling images
- `ecr_repository_arn`: For IAM policy configuration

**IAM Role Outputs:**
- `jenkins_role_arn`: For Jenkins service account annotation
- `argocd_image_updater_role_arn`: For Image Updater service account
- `aws_lb_controller_role_arn`: For Load Balancer Controller
- `eso_role_arn`: For External Secrets Operator
- `nodejs_app_secrets_role_arn`: For application pods

**Helper Outputs:**
- `configure_kubectl`: Ready-to-run command for kubectl setup

**Why this matters:**
- Outputs are used in deployment scripts and README
- They enable dynamic configuration (no hardcoded values)
- Sensitive outputs are marked to prevent accidental exposure

---

### Terraform Modules

Now let's dive into each module...



#### Module 1: VPC (Virtual Private Cloud)

**Location:** `terraform/modules/vpc/`

**Purpose:** Creates the network foundation for all AWS resources.

**Architecture:**

```
Internet
    ↓
Internet Gateway
    ↓
Public Subnets (3 AZs)
    ↓
NAT Gateway
    ↓
Private Subnets (3 AZs)
    ↓
EKS Nodes, RDS, Redis
```

**Resources Created:**

**1. VPC (`aws_vpc.main`):**
- CIDR: 10.0.0.0/16 (65,536 IP addresses)
- DNS hostnames enabled (for EKS)
- DNS support enabled

**2. Internet Gateway (`aws_internet_gateway.main`):**
- Allows public subnets to access the internet
- Required for load balancers and NAT gateway

**3. Elastic IP (`aws_eip.nat`):**
- Static IP address for NAT gateway
- Persists even if NAT gateway is recreated

**4. Public Subnets (3x `aws_subnet.public`):**
- One per availability zone (us-east-1a, us-east-1b, us-east-1c)
- CIDR blocks: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24 (256 IPs each)
- Auto-assign public IPs to instances
- **Special Tags:**
  - `kubernetes.io/role/elb=1`: Tells AWS Load Balancer Controller to use these for public ALBs
  - `kubernetes.io/cluster/gitops-eks-cluster=shared`: EKS cluster discovery

**5. Private Subnets (3x `aws_subnet.private`):**
- One per availability zone
- CIDR blocks: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24
- No public IPs (secure)
- **Special Tags:**
  - `kubernetes.io/role/internal-elb=1`: For internal load balancers
  - `kubernetes.io/cluster/gitops-eks-cluster=shared`: EKS cluster discovery

**6. NAT Gateway (`aws_nat_gateway.main`):**
- Placed in first public subnet
- Allows private subnet resources to access internet (for updates, ECR pulls)
- Costs ~$32/month (always running)

**7. Route Tables:**
- **Public Route Table:** Routes 0.0.0.0/0 → Internet Gateway
- **Private Route Table:** Routes 0.0.0.0/0 → NAT Gateway

**Why 3 Availability Zones?**
- High availability: If one AZ fails, cluster continues running
- EKS best practice: Spread nodes across multiple AZs
- RDS multi-AZ failover support

**Cost Optimization:**
- Single NAT Gateway (not one per AZ) saves ~$64/month
- Trade-off: If NAT Gateway AZ fails, private subnets lose internet access

---



#### Module 2: EKS (Elastic Kubernetes Service)

**Location:** `terraform/modules/eks/`

**Purpose:** Creates a managed Kubernetes cluster for running containerized applications.

**Architecture:**

```
EKS Control Plane (AWS Managed)
    ↓
EKS Node Group (EC2 Instances)
    ↓
Pods (Containers)
```

**Resources Created:**

**1. IAM Role for EKS Cluster (`aws_iam_role.eks_cluster`):**
- Allows EKS service to manage AWS resources
- **Attached Policies:**
  - `AmazonEKSClusterPolicy`: Core EKS permissions
  - `AmazonEKSVPCResourceController`: Manage ENIs and security groups

**2. IAM Role for EKS Node Group (`aws_iam_role.eks_node_group`):**
- Allows EC2 instances to join the cluster
- **Attached Policies:**
  - `AmazonEKSWorkerNodePolicy`: Node registration and management
  - `AmazonEKS_CNI_Policy`: Pod networking (VPC CNI)
  - `AmazonEC2ContainerRegistryReadOnly`: Pull images from ECR

**3. EKS Cluster (`aws_eks_cluster.main`):**
- **Name:** gitops-eks-cluster
- **Version:** Kubernetes 1.28
- **Networking:**
  - Runs in private subnets (secure)
  - Private endpoint enabled (nodes can access API)
  - Public endpoint enabled (kubectl access from internet)
- **Logging:** All control plane logs enabled (API, audit, authenticator, controller manager, scheduler)
- **Cost:** $73/month (EKS control plane)

**4. EKS Node Group (`aws_eks_node_group.main`):**
- **Instance Type:** t3.medium (2 vCPU, 4 GB RAM)
- **Scaling:**
  - Desired: 3 nodes
  - Min: 1 node (cost savings during low usage)
  - Max: 4 nodes (handle traffic spikes)
- **Update Strategy:** Max 1 node unavailable during updates (rolling updates)
- **Placement:** Private subnets across 3 AZs
- **Cost:** ~$60/month (3 × t3.medium instances)

**5. OIDC Provider (`aws_iam_openid_connect_provider.eks`):**
- **Purpose:** Enables IRSA (IAM Roles for Service Accounts)
- **How it works:**
  - Kubernetes service accounts can assume IAM roles
  - No need for AWS credentials in pods
  - Fine-grained permissions per service account
- **Used by:** Jenkins, ArgoCD Image Updater, External Secrets Operator, AWS Load Balancer Controller, nodejs-app

**6. EBS CSI Driver Addon (`aws_eks_addon.ebs_csi_driver`):**
- **Purpose:** Allows pods to use EBS volumes for persistent storage
- **Version:** v1.25.0
- **IAM Role:** Managed by IAM module (can create/attach EBS volumes)
- **Use Cases:** Databases, Jenkins home directory, persistent logs

**Why Managed Node Groups?**
- AWS handles node updates and patching
- Automatic integration with EKS
- Simpler than self-managed nodes

**Security Features:**
- Nodes in private subnets (no direct internet access)
- Control plane logs for audit trail
- IRSA for pod-level IAM permissions
- Security groups automatically configured

---



#### Module 3: RDS (Relational Database Service)

**Location:** `terraform/modules/rds/`

**Purpose:** Creates a managed MySQL database for the application.

**Resources Created:**

**1. Security Group (`aws_security_group.rds`):**
- **Ingress:** Port 3306 (MySQL) from EKS node security group only
- **Egress:** All traffic allowed (for updates)
- **Security:** Database is NOT accessible from internet

**2. DB Subnet Group (`aws_db_subnet_group.main`):**
- Spans all 3 private subnets
- Required for Multi-AZ deployment

**3. RDS Instance (`aws_db_instance.main`):**
- **Engine:** MySQL 8.0
- **Instance Class:** db.t3.micro (1 vCPU, 1 GB RAM)
- **Storage:** 20 GB GP2 (General Purpose SSD)
- **Encryption:** Enabled (data at rest)
- **Multi-AZ:** Enabled (automatic failover to standby in different AZ)
- **Publicly Accessible:** NO (secure)
- **Backup:**
  - Retention: 1 day
  - Window: 03:00-04:00 UTC
- **Maintenance Window:** Monday 04:00-05:00 UTC
- **Cost:** ~$15/month

**4. Secrets Manager Secret (`aws_secretsmanager_secret.rds`):**
- Stores database credentials securely
- **Contents:**
  ```json
  {
    "host": "database-endpoint.rds.amazonaws.com",
    "port": 3306,
    "dbname": "appdb",
    "username": "admin",
    "password": "your-password"
  }
  ```
- **Access:** Only pods with proper IAM role can read
- **Recovery Window:** 0 days (immediate deletion for dev environment)

**Why Multi-AZ?**
- If primary AZ fails, RDS automatically fails over to standby
- Downtime: ~1-2 minutes during failover
- No data loss (synchronous replication)

---

#### Module 4: ElastiCache (Redis)

**Location:** `terraform/modules/elasticache/`

**Purpose:** Creates a managed Redis cache for session storage and caching.

**Resources Created:**

**1. Security Group (`aws_security_group.redis`):**
- **Ingress:** Port 6379 (Redis) from EKS nodes only
- **Egress:** All traffic allowed
- **Security:** Not accessible from internet

**2. ElastiCache Subnet Group (`aws_elasticache_subnet_group.main`):**
- Spans all 3 private subnets

**3. Redis Cluster (`aws_elasticache_cluster.redis`):**
- **Engine:** Redis 7.0
- **Node Type:** cache.t3.micro (0.5 GB memory)
- **Nodes:** 1 (no replication for cost savings)
- **Port:** 6379
- **Parameter Group:** default.redis7
- **Cost:** ~$12/month

**4. Secrets Manager Secret (`aws_secretsmanager_secret.redis`):**
- Stores Redis connection details
- **Contents:**
  ```json
  {
    "host": "redis-endpoint.cache.amazonaws.com",
    "port": 6379
  }
  ```

**Why Redis?**
- Fast in-memory caching (microsecond latency)
- Session storage for web applications
- Rate limiting, leaderboards, real-time analytics

**Single Node vs Replication:**
- Single node: Lower cost, acceptable for dev/test
- Production: Use replication group for high availability

---

#### Module 5: ECR (Elastic Container Registry)

**Location:** `terraform/modules/ecr/`

**Purpose:** Private Docker registry for storing application images.

**Resources Created:**

**1. ECR Repository (`aws_ecr_repository.main`):**
- **Name:** nodejs-app
- **Image Tag Mutability:** MUTABLE (can overwrite tags)
- **Image Scanning:** Enabled (scan for vulnerabilities on push)
- **Encryption:** AES256 (data at rest)
- **Force Delete:** Enabled (can delete even with images)

**2. Lifecycle Policy (`aws_ecr_lifecycle_policy.main`):**
- **Rule:** Keep only last 10 images
- **Purpose:** Automatic cleanup to save storage costs
- **Trigger:** Runs daily

**Image Naming Convention:**
- Jenkins builds images with tags: `build-1`, `build-2`, `build-3`, etc.
- ArgoCD Image Updater uses alphabetical sorting to find latest

**Cost:**
- Storage: $0.10 per GB/month
- Data Transfer: $0.09 per GB (out to internet)
- Typical: ~$1-2/month for small projects

---

#### Module 6: IAM (Identity and Access Management)

**Location:** `terraform/modules/iam/`

**Purpose:** Creates all IAM roles for IRSA (IAM Roles for Service Accounts).

**What is IRSA?**
- Kubernetes service accounts can assume IAM roles
- No AWS credentials stored in pods
- Fine-grained permissions per service account
- Uses OIDC (OpenID Connect) for authentication

**IAM Roles Created:**

**1. Jenkins Role (`aws_iam_role.jenkins`):**
- **Service Account:** `jenkins:jenkins`
- **Permissions:**
  - `ecr:GetAuthorizationToken`: Login to ECR
  - `ecr:PutImage`: Push Docker images
  - `ecr:InitiateLayerUpload`, `CompleteLayerUpload`: Upload image layers
- **Use Case:** Jenkins pipeline pushes built images to ECR

**2. ArgoCD Image Updater Role (`aws_iam_role.argocd_image_updater`):**
- **Service Account:** `argocd:argocd-image-updater`
- **Permissions:**
  - `ecr:GetAuthorizationToken`: Login to ECR
  - `ecr:DescribeImages`, `ListImages`: Check for new images
  - `ecr:BatchGetImage`: Pull image manifests
- **Use Case:** Image Updater checks ECR every 2 minutes for new builds

**3. External Secrets Operator Role (`aws_iam_role.eso`):**
- **Service Account:** `nodejs-app:nodejs-app-sa`
- **Permissions:**
  - `secretsmanager:GetSecretValue`: Read secrets
  - `secretsmanager:DescribeSecret`: Get secret metadata
- **Resources:** RDS and Redis secrets only
- **Use Case:** Sync secrets from AWS Secrets Manager to Kubernetes secrets

**4. AWS Load Balancer Controller Role (`aws_iam_role.aws_load_balancer_controller`):**
- **Service Account:** `kube-system:aws-load-balancer-controller`
- **Permissions:** (from `policies/aws-lb-controller-policy.json`)
  - Create/delete ALBs, target groups, listeners
  - Manage security groups
  - Describe EC2 instances, subnets, VPCs
- **Use Case:** Automatically creates ALB when Ingress resource is created

**5. EBS CSI Driver Role (`aws_iam_role.ebs_csi_driver`):**
- **Service Account:** `kube-system:ebs-csi-controller-sa`
- **Permissions:** (from `policies/ebs-csi-driver-policy.json`)
  - Create/attach/delete EBS volumes
  - Create/delete snapshots
  - Tag volumes
- **Use Case:** Provision persistent volumes for pods

**6. nodejs-app Secrets Role (`aws_iam_role.nodejs_app_secrets`):**
- **Service Account:** `nodejs-app:nodejs-app-sa`
- **Permissions:**
  - Read RDS and Redis secrets from Secrets Manager
- **Use Case:** Application pods access database credentials

**IRSA Trust Policy Pattern:**
```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks..."
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "oidc.eks...:sub": "system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT",
      "oidc.eks...:aud": "sts.amazonaws.com"
    }
  }
}
```

**How IRSA Works:**
1. Pod starts with service account annotation: `eks.amazonaws.com/role-arn=ROLE_ARN`
2. EKS injects AWS credentials as environment variables
3. AWS SDK automatically uses these credentials
4. Credentials are temporary (expire after 1 hour, auto-renewed)

**Security Benefits:**
- No long-lived credentials in pods
- Automatic credential rotation
- Audit trail in CloudTrail
- Principle of least privilege (each service account has minimal permissions)

---

### Additional Terraform Files

#### `terraform/jenkins-helm-values.yaml`

**Purpose:** Helm values for Jenkins installation.

**Key Configurations:**
- **Persistence:** 8 GB EBS volume for Jenkins home
- **Service Account:** Named `jenkins` (for IRSA)
- **Resources:** 2 CPU, 4 GB RAM
- **Plugins:** Pre-installed (Git, Pipeline, Kubernetes, Docker)
- **Security:** Admin password stored in Kubernetes secret

---

### Terraform Workflow

**Initialization:**
```bash
terraform init
```
- Downloads AWS provider
- Initializes modules

**Planning:**
```bash
terraform plan -var="db_password=YourPassword"
```
- Shows what will be created
- No changes made

**Applying:**
```bash
terraform apply -var="db_password=YourPassword" -auto-approve
```
- Creates all resources
- Takes ~15 minutes
- Order: VPC → EKS → RDS/ElastiCache/ECR → IAM

**Destroying:**
```bash
terraform destroy -var="db_password=YourPassword" -auto-approve
```
- Deletes all resources
- **Important:** Delete ALBs and security groups first (created by Kubernetes, not Terraform)

---

## Kubernetes Manifests

Now let's explain the Kubernetes configuration files...



### ArgoCD Configuration Files

**Location:** `k8s/argocd/`

#### 1. `application-no-annotations.yaml`

**Purpose:** ArgoCD Application manifest that defines what to deploy and how.

**Key Components:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nodejs-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # Ensures cleanup on deletion
```

**Finalizer Explained:**
- When you delete the Application, ArgoCD deletes all resources it created
- Without finalizer: Application deleted, but pods/services remain orphaned
- With finalizer: Clean deletion of everything

**Source Configuration:**
```yaml
source:
  repoURL: https://github.com/YOUR_REPO.git
  targetRevision: main
  path: k8s/helm-chart/nodejs-app
  helm:
    parameters:
    - name: image.repository
      value: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/nodejs-app
    - name: image.tag
      value: latest
```

- **repoURL:** Git repository containing Helm chart
- **targetRevision:** Branch to track (main)
- **path:** Location of Helm chart in repo
- **helm.parameters:** Override values.yaml dynamically

**Destination:**
```yaml
destination:
  server: https://kubernetes.default.svc  # Deploy to same cluster
  namespace: nodejs-app
```

**Sync Policy:**
```yaml
syncPolicy:
  automated:
    prune: true        # Delete resources not in Git
    selfHeal: true     # Revert manual changes
    allowEmpty: false  # Don't delete everything if Git is empty
  syncOptions:
    - CreateNamespace=true  # Auto-create namespace
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

**Automated Sync Explained:**
- **prune:** If you delete a file from Git, ArgoCD deletes the resource
- **selfHeal:** If someone runs `kubectl edit`, ArgoCD reverts it
- **Retry:** If sync fails, retry with exponential backoff (5s, 10s, 20s, 40s, 80s)

---

#### 2. `imageupdater-cr.yaml`

**Purpose:** Custom Resource for ArgoCD Image Updater v1.0.0 (CR-based approach).

**Key Components:**

```yaml
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: nodejs-app-updater
  namespace: argocd
spec:
  namespace: argocd  # Where to find Applications
  
  commonUpdateSettings:
    updateStrategy: alphabetical  # Sort tags lexically
    ignoreTags:
      - "latest"  # Don't consider 'latest' tag
      - "v*"      # Ignore version tags like v1.0.0
```

**Update Strategies:**
- **alphabetical:** `build-10` > `build-9` > `build-2` (lexical sorting)
- **semver:** `v1.2.3` > `v1.2.2` (semantic versioning)
- **latest:** Use most recently pushed image
- **digest:** Track by image digest (SHA256)

**Write-Back Configuration:**
```yaml
writeBackConfig:
  method: argocd  # Update Application spec directly
```

**Methods:**
- **argocd:** Update Application manifest in ArgoCD (no Git commit)
- **git:** Commit changes to Git repository (full GitOps)

**Application Reference:**
```yaml
applicationRefs:
  - namePattern: "nodejs-app"  # Match Application by name
    images:
      - alias: nodejs-app
        imageName: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/nodejs-app:latest
        manifestTargets:
          helm:
            name: image.repository  # Update this Helm value
            tag: image.tag          # Update this Helm value
```

**How It Works:**
1. Every 2 minutes, Image Updater checks ECR for new images
2. Finds all tags matching pattern (build-1, build-2, build-3, ...)
3. Ignores `latest` and `v*` tags
4. Sorts remaining tags alphabetically
5. If highest tag is newer than current, updates Application
6. ArgoCD detects change and syncs new image

---

#### 3. `image-updater-values.yaml`

**Purpose:** Helm values for installing ArgoCD Image Updater.

**Service Account Annotation:**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/argocd-image-updater-role
```
- Enables IRSA (IAM role for ECR access)

**ECR Registry Configuration:**
```yaml
config:
  registries:
    - name: ecr
      api_url: https://ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
      prefix: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
      credentials: ext:/scripts/ecr-login.sh  # Use custom auth script
      default: true
```

**Authentication Script:**
```yaml
authScripts:
  enabled: true
  scripts:
    ecr-login.sh: |
      #!/bin/sh
      export HOME=/tmp
      echo "AWS:$(aws ecr get-login-password --region us-east-1)"
```

**How ECR Authentication Works:**
1. Image Updater needs to check ECR for new images
2. ECR requires authentication (token expires every 12 hours)
3. Script runs `aws ecr get-login-password` using IRSA credentials
4. Returns token in format: `AWS:eyJwYXlsb2FkIjoi...`
5. Image Updater uses token to authenticate to ECR

---

### Helm Chart

**Location:** `k8s/helm-chart/nodejs-app/`

#### `Chart.yaml`

**Purpose:** Helm chart metadata.

```yaml
apiVersion: v2
name: nodejs-app
description: A Helm chart for Node.js application with RDS and Redis
type: application
version: 1.0.0      # Chart version
appVersion: "1.0.0" # Application version
```

---

#### `values.yaml`

**Purpose:** Default configuration values for the Helm chart.

**Replica Configuration:**
```yaml
replicaCount: 3  # Run 3 pods for high availability
```

**Image Configuration:**
```yaml
image:
  repository: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/nodejs-app
  tag: latest
  pullPolicy: Always  # Always pull image (important for 'latest' tag)
```

**Service Configuration:**
```yaml
service:
  type: ClusterIP  # Internal service (not exposed to internet)
  port: 80         # Service listens on port 80
  targetPort: 3000 # Forward to container port 3000
```

**Resource Limits:**
```yaml
resources:
  requests:
    cpu: 100m      # Minimum: 0.1 CPU core
    memory: 128Mi  # Minimum: 128 MB RAM
  limits:
    cpu: 500m      # Maximum: 0.5 CPU core
    memory: 512Mi  # Maximum: 512 MB RAM
```

**Health Checks:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30  # Wait 30s before first check
  periodSeconds: 10        # Check every 10s
  failureThreshold: 3      # Restart after 3 failures

readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10  # Wait 10s before first check
  periodSeconds: 5         # Check every 5s
  failureThreshold: 3      # Remove from service after 3 failures
```

**Liveness vs Readiness:**
- **Liveness:** Is the pod alive? If not, restart it
- **Readiness:** Is the pod ready to serve traffic? If not, remove from load balancer

**External Secrets Configuration:**
```yaml
secrets:
  rds:
    enabled: true
    secretName: rds-secret
    remoteRef: aws-gitops-pipeline-dev-rds-credentials
  redis:
    enabled: true
    secretName: redis-secret
    remoteRef: aws-gitops-pipeline-dev-redis-credentials

externalSecrets:
  enabled: true
  secretStore:
    name: aws-secrets-manager
    region: us-east-1
```

**Ingress Configuration:**
```yaml
ingress:
  enabled: true
  scheme: internet-facing  # Public ALB
  targetType: ip           # Route to pod IPs (not node IPs)
  certificateArn: ""       # Optional: HTTPS certificate
```

---

### Helm Templates

**Location:** `k8s/helm-chart/nodejs-app/templates/`

#### `deployment.yaml`

**Purpose:** Defines the Deployment resource (manages pods).

**Key Features:**

**Service Account:**
```yaml
serviceAccountName: {{ .Values.serviceAccount.name }}
```
- Pods use this service account for IRSA

**Environment Variables from Secrets:**
```yaml
envFrom:
- secretRef:
    name: rds-secret    # DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
- secretRef:
    name: redis-secret  # REDIS_HOST, REDIS_PORT
```
- All secret keys become environment variables
- Application reads them using `process.env.DB_HOST`

**Health Checks:**
- Liveness probe: Restart unhealthy pods
- Readiness probe: Remove unready pods from service

**Resource Limits:**
- Prevents pods from consuming all cluster resources
- Enables Kubernetes to schedule pods efficiently

---

#### `externalsecret-rds.yaml`

**Purpose:** Syncs RDS credentials from AWS Secrets Manager to Kubernetes Secret.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: rds-external-secret
spec:
  refreshInterval: 1h  # Sync every hour
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: rds-secret  # Create this Kubernetes Secret
    creationPolicy: Owner
  data:
    - secretKey: DB_HOST
      remoteRef:
        key: aws-gitops-pipeline-dev-rds-credentials
        property: host
    - secretKey: DB_PORT
      remoteRef:
        key: aws-gitops-pipeline-dev-rds-credentials
        property: port
    # ... more fields
```

**How It Works:**
1. External Secrets Operator reads this ExternalSecret
2. Uses SecretStore to authenticate to AWS Secrets Manager
3. Fetches secret: `aws-gitops-pipeline-dev-rds-credentials`
4. Extracts properties: `host`, `port`, `dbname`, `username`, `password`
5. Creates Kubernetes Secret: `rds-secret` with keys: `DB_HOST`, `DB_PORT`, etc.
6. Pods mount this secret as environment variables

---

#### `secretstore.yaml`

**Purpose:** Configures how to authenticate to AWS Secrets Manager.

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: nodejs-app-sa  # Use this service account's IAM role
```

**Authentication Flow:**
1. SecretStore references service account: `nodejs-app-sa`
2. Service account has annotation: `eks.amazonaws.com/role-arn=ROLE_ARN`
3. EKS injects AWS credentials into pods using this service account
4. External Secrets Operator uses these credentials to access Secrets Manager

---

#### `ingress.yaml`

**Purpose:** Creates an Application Load Balancer (ALB) for external access.

**Key Annotations:**
```yaml
annotations:
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
  alb.ingress.kubernetes.io/healthcheck-path: /health
```

**Annotations Explained:**
- **scheme:** `internet-facing` (public) or `internal` (private VPC only)
- **target-type:** `ip` (route to pod IPs) or `instance` (route to node IPs)
- **listen-ports:** HTTP on port 80 (add HTTPS 443 if certificate provided)
- **healthcheck-path:** ALB checks `/health` endpoint

**How ALB Works:**
1. AWS Load Balancer Controller watches Ingress resources
2. When Ingress is created, controller creates ALB in AWS
3. ALB is placed in public subnets
4. Target group points to pod IPs in private subnets
5. ALB performs health checks on `/health`
6. Traffic flows: Internet → ALB → Pods

**Cost:** ~$16/month per ALB

---

## Application Files

### Jenkinsfile

**Location:** `nodejs-app/Jenkinsfile`

**Purpose:** Defines CI/CD pipeline for building and pushing Docker images.

**Pipeline Stages:**

**1. Agent Configuration:**
```groovy
agent {
  kubernetes {
    yaml '''
    spec:
      serviceAccountName: jenkins
      containers:
      - name: kaniko
        image: gcr.io/kaniko-project/executor:debug
      - name: aws-cli
        image: amazon/aws-cli:latest
    '''
  }
}
```

**Why Kubernetes Agent?**
- Jenkins runs in Kubernetes
- Each build runs in a temporary pod
- Pod has 2 containers: `kaniko` (build images) and `aws-cli` (ECR auth)
- Pod uses `jenkins` service account (has IRSA for ECR access)

**2. Setup Environment:**
```groovy
env.AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
env.ECR_REPOSITORY_URL = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/nodejs-app"
env.IMAGE_TAG = "build-${BUILD_NUMBER}"
```

**Dynamic Configuration:**
- Gets AWS account ID at runtime (no hardcoding!)
- Constructs ECR URL dynamically
- Tags image with build number: `build-1`, `build-2`, `build-3`, ...

**3. Setup ECR Authentication:**
```groovy
aws ecr get-login-password --region ${AWS_REGION} > /tmp/ecr-password

cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "${ECR_REGISTRY}": {
      "auth": "$(echo -n AWS:$(cat /tmp/ecr-password) | base64 -w 0)"
    }
  }
}
EOF
```

**ECR Authentication:**
- Gets temporary password from ECR (valid 12 hours)
- Creates Docker config file for Kaniko
- Kaniko uses this to push images

**4. Build and Push Image:**
```groovy
/kaniko/executor \
  --context=${WORKSPACE}/nodejs-app \
  --dockerfile=${WORKSPACE}/nodejs-app/Dockerfile \
  --destination=${ECR_REPOSITORY_URL}:${IMAGE_TAG} \
  --destination=${ECR_REPOSITORY_URL}:latest \
  --cache=true \
  --cache-ttl=24h
```

**Kaniko Explained:**
- Builds Docker images inside Kubernetes (no Docker daemon needed)
- Pushes 2 tags: `build-X` and `latest`
- Uses layer caching for faster builds

**Pipeline Flow:**
```
Git Push → Jenkins Webhook → Build Pod Created → 
Checkout Code → Build Image → Push to ECR → 
Image Updater Detects → ArgoCD Syncs → Pods Updated
```

---

### Dockerfile

**Location:** `nodejs-app/Dockerfile`

**Purpose:** Defines how to build the Node.js application container.

**Multi-Stage Build:**

**1. Base Image:**
```dockerfile
FROM node:18-alpine
```
- Uses Alpine Linux (5 MB vs 900 MB for full Node image)
- Node.js 18 LTS

**2. Install Dependencies:**
```dockerfile
COPY package*.json ./
RUN npm install --production
```
- Copy only package files first (layer caching)
- Install production dependencies only (no dev tools)

**3. Copy Application Code:**
```dockerfile
COPY src/ ./src/
COPY public/ ./public/
```
- Copy source code and static files

**4. Security:**
```dockerfile
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app
USER nodejs
```
- Create non-root user
- Run application as `nodejs` user (not root)
- Prevents privilege escalation attacks

**5. Health Check:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"
```
- Docker checks `/health` endpoint every 30 seconds
- If 3 consecutive failures, container marked unhealthy

**6. Start Application:**
```dockerfile
CMD ["node", "src/index.js"]
```
- Runs Node.js directly (no npm, faster startup)

**Image Size Optimization:**
- Alpine base: ~50 MB
- Production dependencies only
- No build tools or dev dependencies
- Final image: ~100-150 MB

---

## Complete GitOps Flow

### 1. Developer Workflow

```
Developer → Git Push → GitHub
```

### 2. CI Pipeline (Jenkins)

```
GitHub Webhook → Jenkins → Build Pod
  ↓
Checkout Code
  ↓
Build Docker Image (Kaniko)
  ↓
Push to ECR (build-X, latest)
```

### 3. CD Pipeline (ArgoCD)

```
Image Updater (every 2 min) → Check ECR
  ↓
New build-X found?
  ↓
Update Application Spec
  ↓
ArgoCD Detects Change
  ↓
Sync to Cluster
  ↓
Rolling Update (3 pods)
  ↓
Health Checks Pass
  ↓
Traffic Routed to New Pods
```

### 4. Runtime

```
Internet → ALB → Service → Pods
                              ↓
                         RDS (MySQL)
                              ↓
                         Redis (Cache)
```

---

## Security Features

### 1. Network Security
- **Private Subnets:** EKS nodes, RDS, Redis not accessible from internet
- **Security Groups:** Fine-grained firewall rules
- **NAT Gateway:** Outbound internet access for updates

### 2. IAM Security
- **IRSA:** No AWS credentials in pods
- **Least Privilege:** Each service account has minimal permissions
- **Temporary Credentials:** Auto-rotate every hour

### 3. Secrets Management
- **AWS Secrets Manager:** Encrypted at rest
- **External Secrets Operator:** Sync to Kubernetes
- **No Hardcoded Secrets:** All secrets injected at runtime

### 4. Container Security
- **Non-Root User:** Containers run as unprivileged user
- **Image Scanning:** ECR scans for vulnerabilities
- **Read-Only Filesystem:** (can be enabled)

### 5. Kubernetes Security
- **RBAC:** Role-based access control
- **Network Policies:** (can be added)
- **Pod Security Standards:** (can be enforced)

---

## Cost Breakdown

### Monthly Costs (us-east-1)

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| EKS Control Plane | 1 cluster | $73 |
| EC2 Instances | 3 × t3.medium | $60 |
| RDS MySQL | db.t3.micro, Multi-AZ | $15 |
| ElastiCache Redis | cache.t3.micro | $12 |
| Application Load Balancer | 1 ALB | $16 |
| NAT Gateway | 1 NAT + data transfer | $32 |
| EBS Volumes | 3 × 20 GB (nodes) + 8 GB (Jenkins) | $5 |
| ECR Storage | ~5 GB | $0.50 |
| Secrets Manager | 2 secrets | $0.80 |
| Data Transfer | Minimal | $5 |
| **Total** | | **~$213/month** |

### Cost Optimization Tips

**Development:**
- Scale nodes to 1 during off-hours
- Use Spot Instances (60-90% savings)
- Delete ALB when not testing

**Production:**
- Reserved Instances (40% savings)
- Savings Plans
- Use smaller instance types if possible

---

## Troubleshooting Guide

### Common Issues

**1. Pods Not Starting:**
- Check: `kubectl describe pod POD_NAME -n nodejs-app`
- Common causes: Image pull errors, secret not found, insufficient resources

**2. External Secrets Not Syncing:**
- Check: `kubectl get externalsecret -n nodejs-app`
- Verify: Service account has IAM role annotation
- Check: External Secrets Operator logs

**3. ALB Not Creating:**
- Check: AWS Load Balancer Controller logs
- Verify: Service account has IAM role
- Check: Subnets have correct tags

**4. Image Updater Not Detecting Images:**
- Check: Image Updater logs
- Verify: ECR authentication working
- Check: Image tags match pattern (build-X)

**5. ArgoCD Application Degraded:**
- Check: `kubectl get application nodejs-app -n argocd -o yaml`
- Look at: `.status.conditions`
- Common causes: Invalid Helm values, missing secrets

---

## Best Practices

### 1. GitOps
- ✅ All configuration in Git
- ✅ Automated sync with ArgoCD
- ✅ Self-healing enabled
- ✅ Prune orphaned resources

### 2. Security
- ✅ IRSA for all AWS access
- ✅ Secrets in AWS Secrets Manager
- ✅ Non-root containers
- ✅ Private subnets for workloads

### 3. High Availability
- ✅ Multi-AZ deployment
- ✅ 3 pod replicas
- ✅ RDS Multi-AZ
- ✅ Health checks configured

### 4. Observability
- ✅ EKS control plane logs
- ✅ Application health checks
- ✅ ALB health checks
- ⚠️ Add: Prometheus + Grafana
- ⚠️ Add: Centralized logging (ELK/Loki)

### 5. CI/CD
- ✅ Automated builds
- ✅ Automated deployments
- ✅ Image scanning
- ✅ Rolling updates
- ⚠️ Add: Automated tests
- ⚠️ Add: Canary deployments

---

## Next Steps

### Enhancements

**1. Monitoring:**
- Install Prometheus + Grafana
- Set up alerts (Slack/PagerDuty)
- Add custom metrics

**2. Logging:**
- Install Fluent Bit
- Send logs to CloudWatch/Elasticsearch
- Set up log-based alerts

**3. Security:**
- Enable Pod Security Standards
- Add Network Policies
- Implement OPA/Gatekeeper

**4. Performance:**
- Add Horizontal Pod Autoscaler
- Configure Cluster Autoscaler
- Implement caching strategies

**5. Disaster Recovery:**
- Automated backups (Velero)
- Multi-region deployment
- Disaster recovery runbooks

---

**End of Architecture Explanation**

This document covers the complete architecture of the AWS GitOps Pipeline project. For questions or improvements, please refer to the README.md or open an issue in the repository.

