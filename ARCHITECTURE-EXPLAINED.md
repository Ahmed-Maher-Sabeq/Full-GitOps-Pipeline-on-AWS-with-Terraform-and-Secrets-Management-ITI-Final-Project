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

