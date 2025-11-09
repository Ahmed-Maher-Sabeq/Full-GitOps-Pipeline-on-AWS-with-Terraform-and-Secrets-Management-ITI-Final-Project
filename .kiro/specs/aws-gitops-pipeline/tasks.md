# Implementation Plan

- [x] 1. Set up Terraform project structure and variables


  - Create variables.tf with all required input variables (project_name, environment, vpc_cidr, availability_zones, etc.)
  - Create outputs.tf for root module outputs
  - Create terraform.tfvars with default values
  - Update provider.tf to reference project variables
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

- [x] 2. Implement VPC Terraform module


  - [ ] 2.1 Create VPC module structure
    - Create modules/vpc directory with main.tf, variables.tf, outputs.tf
    - Define input variables for CIDR blocks and availability zones

    - _Requirements: 1.1_
  
  - [x] 2.2 Implement VPC resources

    - Create VPC with DNS support enabled
    - Create 3 public subnets across 3 AZs with auto-assign public IP
    - Create 3 private subnets across 3 AZs
    - Create Internet Gateway and attach to VPC
    - Create Elastic IP for NAT Gateway
    - Create NAT Gateway in first public subnet
    - _Requirements: 1.1, 1.2_
  


  - [ ] 2.3 Implement routing configuration
    - Create route table for public subnets with route to Internet Gateway
    - Associate public subnets with public route table
    - Create route table for private subnets with route to NAT Gateway
    - Associate private subnets with private route table

    - _Requirements: 1.2_
  
  - [ ] 2.4 Add VPC module outputs
    - Output vpc_id, public_subnet_ids, private_subnet_ids, nat_gateway_id


    - _Requirements: 1.1_

- [x] 3. Implement EKS Terraform module


  - [ ] 3.1 Create EKS module structure
    - Create modules/eks directory with main.tf, variables.tf, outputs.tf
    - Define input variables for cluster configuration
    - _Requirements: 1.3_
  


  - [ ] 3.2 Implement IAM roles for EKS
    - Create IAM role for EKS cluster with trust policy
    - Attach AmazonEKSClusterPolicy and AmazonEKSVPCResourceController policies
    - Create IAM role for node group with trust policy


    - Attach AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly policies
    - _Requirements: 1.3_
  
  - [x] 3.3 Implement EKS cluster


    - Create EKS cluster in private subnets
    - Configure cluster endpoint access (public and private)
    - Enable cluster logging

    - _Requirements: 1.3_
  
  - [ ] 3.4 Implement EKS node group
    - Create managed node group in private subnets
    - Configure instance types, desired/min/max sizes


    - Configure node group scaling and update config
    - _Requirements: 1.3_
  


  - [ ] 3.5 Implement OIDC provider for IRSA
    - Create OIDC identity provider for the cluster
    - Output OIDC provider ARN for service account IAM roles


    - _Requirements: 1.3_
  


  - [ ] 3.6 Add EKS module outputs
    - Output cluster_id, cluster_endpoint, cluster_certificate_authority_data
    - Output cluster_security_group_id, node_security_group_id, oidc_provider_arn
    - _Requirements: 1.3_



- [ ] 4. Implement RDS Terraform module
  - [ ] 4.1 Create RDS module structure
    - Create modules/rds directory with main.tf, variables.tf, outputs.tf

    - Define input variables for database configuration
    - _Requirements: 1.4_
  
  - [x] 4.2 Implement RDS security group


    - Create security group for RDS instance
    - Add ingress rule allowing MySQL traffic (port 3306) from EKS node security group
    - _Requirements: 1.4_


  
  - [ ] 4.3 Implement RDS subnet group
    - Create DB subnet group spanning all private subnets


    - _Requirements: 1.4_
  


  - [ ] 4.4 Implement RDS instance
    - Create RDS MySQL instance with multi-AZ deployment
    - Configure instance class, allocated storage, engine version
    - Enable automated backups with retention period


    - Configure database name, master username, and password
    - _Requirements: 1.4_
  

  - [ ] 4.5 Store RDS credentials in AWS Secrets Manager
    - Create AWS Secrets Manager secret with RDS connection details (host, port, dbname, username, password)
    - Output secret ARN
    - _Requirements: 1.8_


  
  - [ ] 4.6 Add RDS module outputs
    - Output db_endpoint, db_port, db_name, db_secret_arn


    - _Requirements: 1.4_

- [x] 5. Implement ElastiCache Terraform module


  - [ ] 5.1 Create ElastiCache module structure
    - Create modules/elasticache directory with main.tf, variables.tf, outputs.tf

    - Define input variables for Redis configuration
    - _Requirements: 1.5_
  
  - [x] 5.2 Implement ElastiCache security group


    - Create security group for ElastiCache cluster
    - Add ingress rule allowing Redis traffic (port 6379) from EKS node security group


    - _Requirements: 1.5_
  
  - [x] 5.3 Implement ElastiCache subnet group


    - Create cache subnet group spanning all private subnets
    - _Requirements: 1.5_
  


  - [ ] 5.4 Implement ElastiCache Redis cluster
    - Create ElastiCache Redis cluster
    - Configure node type, number of cache nodes, engine version


    - Enable automatic failover if multi-node
    - _Requirements: 1.5_

  
  - [ ] 5.5 Store Redis credentials in AWS Secrets Manager
    - Create AWS Secrets Manager secret with Redis connection details (host, port)




    - Output secret ARN
    - _Requirements: 1.8_
  
  - [ ] 5.6 Add ElastiCache module outputs
    - Output redis_endpoint, redis_port, redis_secret_arn
    - _Requirements: 1.5_

- [ ] 6. Implement ECR Terraform module
  - [ ] 6.1 Create ECR module structure
    - Create modules/ecr directory with main.tf, variables.tf, outputs.tf
    - Define input variables for repository configuration
    - _Requirements: 1.6_
  
  - [ ] 6.2 Implement ECR repository
    - Create ECR repository with image scanning enabled
    - Configure image tag mutability
    - _Requirements: 1.6_
  
  - [ ] 6.3 Implement ECR lifecycle policy
    - Create lifecycle policy to retain last 10 images
    - _Requirements: 1.6_
  
  - [ ] 6.4 Add ECR module outputs
    - Output repository_url, repository_arn
    - _Requirements: 1.6_

- [ ] 7. Wire up root Terraform module
  - [ ] 7.1 Integrate VPC module in root main.tf
    - Call VPC module with required variables
    - _Requirements: 1.1, 1.2_
  
  - [ ] 7.2 Integrate EKS module in root main.tf
    - Call EKS module with VPC outputs
    - Pass private subnet IDs to EKS module
    - _Requirements: 1.3_
  
  - [ ] 7.3 Integrate RDS module in root main.tf
    - Call RDS module with VPC outputs and EKS node security group
    - Pass private subnet IDs to RDS module
    - _Requirements: 1.4_
  
  - [ ] 7.4 Integrate ElastiCache module in root main.tf
    - Call ElastiCache module with VPC outputs and EKS node security group
    - Pass private subnet IDs to ElastiCache module
    - _Requirements: 1.5_
  
  - [ ] 7.5 Integrate ECR module in root main.tf
    - Call ECR module with repository name
    - _Requirements: 1.6_
  
  - [ ] 7.6 Add root module outputs
    - Output all important values from child modules (cluster endpoint, RDS endpoint, Redis endpoint, ECR URL, etc.)
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.6_

- [ ] 8. Deploy and test Terraform infrastructure
  - Run terraform init to initialize modules and providers
  - Run terraform plan to review planned changes
  - Run terraform apply to create all infrastructure
  - Verify VPC, subnets, and routing tables created correctly
  - Configure kubectl to access EKS cluster
  - Verify EKS cluster accessible and nodes running
  - Test RDS connectivity from a test pod in EKS
  - Test ElastiCache connectivity from a test pod in EKS
  - Verify ECR repository created
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

- [ ] 9. Create Node.js application structure
  - [x] 9.1 Initialize Node.js project


    - Create nodejs-app directory
    - Initialize package.json with dependencies (express, mysql2, redis)
    - Create src directory structure (config, routes, middleware)
    - _Requirements: 2.1_
  
  - [x] 9.2 Implement database configuration


    - Create src/config/database.js with MySQL connection pool
    - Use environment variables for connection parameters
    - Implement connection error handling and retry logic
    - _Requirements: 2.2_
  
  - [x] 9.3 Implement Redis configuration


    - Create src/config/redis.js with Redis client setup
    - Use environment variables for connection parameters
    - Implement connection error handling and reconnection logic
    - _Requirements: 2.3_
  
  - [x] 9.4 Create database initialization


    - Create src/config/init-db.js to create items table on startup
    - _Requirements: 2.4_

- [ ] 10. Implement Node.js API endpoints
  - [x] 10.1 Implement health check endpoint


    - Create GET /health endpoint that checks MySQL and Redis connectivity
    - Return status with connection states
    - _Requirements: 2.1_
  
  - [x] 10.2 Implement cache middleware


    - Create src/middleware/cache.js for Redis caching logic
    - Implement cache check, cache set, and cache invalidation functions
    - _Requirements: 2.5, 2.6, 2.7_
  
  - [x] 10.3 Implement items API routes


    - Create src/routes/api.js with items endpoints
    - Implement POST /api/items to create new item in MySQL
    - Implement GET /api/items/:id to retrieve item with caching
    - Implement GET /api/items to list all items with caching
    - _Requirements: 2.4, 2.5, 2.6, 2.7_
  
  - [x] 10.4 Create Express server entry point


    - Create src/index.js with Express app setup
    - Register routes and middleware
    - Start server on port 3000
    - _Requirements: 2.1_

- [ ] 11. Create Dockerfile and test application
  - [x] 11.1 Create Dockerfile


    - Create Dockerfile with Node.js 18 Alpine base image
    - Copy package files and run npm ci
    - Copy source code and expose port 3000
    - _Requirements: 2.8_
  
  - [x] 11.2 Create .dockerignore


    - Add node_modules, .git, and other unnecessary files
    - _Requirements: 2.8_
  
  - [x] 11.3 Test application locally


    - Build Docker image locally
    - Run container with environment variables pointing to RDS and ElastiCache
    - Test health endpoint
    - Test all API endpoints (create item, get item, list items)
    - Verify caching behavior
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

- [ ] 12. Set up Jenkins in EKS cluster
  - [x] 12.1 Create IAM role for Jenkins service account


    - Create IAM policy with ECR push permissions (ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, ecr:PutImage, ecr:InitiateLayerUpload, ecr:UploadLayerPart, ecr:CompleteLayerUpload)
    - Create IAM role with trust policy for EKS OIDC provider
    - Attach policy to role
    - _Requirements: 3.1_
  
  - [x] 12.2 Create Jenkins namespace and service account


    - Create jenkins namespace in EKS
    - Create service account with IAM role annotation
    - _Requirements: 3.1, 3.2_
  
  - [x] 12.3 Install Jenkins via Helm


    - Add Jenkins Helm repository
    - Create values.yaml for Jenkins configuration (persistence, service type, plugins)
    - Install Jenkins using Helm with custom values
    - _Requirements: 3.1_
  
  - [ ] 12.4 Access Jenkins and complete setup
    - Get Jenkins admin password from Kubernetes secret
    - Port-forward to Jenkins service for initial access
    - Complete Jenkins initial setup wizard
    - _Requirements: 3.1_



- [ ] 13. Create and configure Jenkins pipeline
  - [ ] 13.1 Create Jenkinsfile in application repository
    - Define pipeline with stages: Checkout, Build, Push to ECR, Notify

    - Configure Git checkout stage
    - _Requirements: 3.8_
  
  - [x] 13.2 Implement Docker build stage

    - Add Docker build commands with commit SHA tag
    - Tag image with both commit SHA and "latest"
    - _Requirements: 3.4, 3.5_
  
  - [x] 13.3 Implement ECR push stage


    - Add AWS ECR login command
    - Push image with commit SHA tag
    - Push image with "latest" tag
    - _Requirements: 3.6, 3.7_
  
  - [ ] 13.4 Implement notification stage
    - Log build status and image details
    - _Requirements: 3.8_
  
  - [ ] 13.5 Create Jenkins pipeline job
    - Create new pipeline job in Jenkins
    - Configure to use Jenkinsfile from Git repository
    - _Requirements: 3.8_
  
  - [ ] 13.6 Test Jenkins pipeline
    - Trigger pipeline manually
    - Verify all stages complete successfully
    - Check ECR for pushed images
    - _Requirements: 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 14. Create Kubernetes manifests repository





  - [ ] 14.1 Initialize manifests repository
    - Create k8s-manifests Git repository
    - Create directory structure (application/, argocd/)

    - _Requirements: 4.7_
  
  - [x] 14.2 Create application namespace manifest


    - Create application/namespace.yaml for app namespace
    - _Requirements: 4.7_


  
  - [ ] 14.3 Create application service account
    - Create application/serviceaccount.yaml for nodejs-app-sa
    - _Requirements: 4.7_
  
  - [x] 14.4 Create application deployment manifest


    - Create application/deployment.yaml with 3 replicas





    - Configure container image from ECR
    - Add envFrom for rds-secret and redis-secret
    - Configure liveness and readiness probes
    - Set resource requests and limits


    - _Requirements: 4.7_
  
  - [ ] 14.5 Create application service manifest
    - Create application/service.yaml with ClusterIP type


    - Expose port 80 targeting container port 3000
    - _Requirements: 4.7_



- [ ] 15. Install and configure ArgoCD
  - [ ] 15.1 Install ArgoCD via Helm
    - Create argocd namespace
    - Add ArgoCD Helm repository
    - Install ArgoCD using Helm


    - _Requirements: 4.1, 4.2_
  
  - [ ] 15.2 Access ArgoCD UI
    - Get ArgoCD admin password
    - Port-forward to ArgoCD server for access
    - Login to ArgoCD UI
    - _Requirements: 4.1_
  
  - [ ] 15.3 Configure Git repository in ArgoCD
    - Add k8s-manifests repository to ArgoCD
    - Configure repository credentials if private
    - _Requirements: 4.3_
  
  - [ ] 15.4 Create ArgoCD Application resource
    - Create argocd/application.yaml manifest
    - Configure source repository, path, and target revision
    - Configure destination cluster and namespace
    - Enable automated sync with prune and self-heal
    - _Requirements: 4.3, 4.4, 4.5_
  
  - [ ] 15.5 Apply ArgoCD Application
    - Apply application.yaml to create ArgoCD application
    - Verify application synced successfully
    - Check pods running in app namespace
    - _Requirements: 4.3, 4.4, 4.5_

- [ ] 16. Install and configure Argo Image Updater
  - [ ] 16.1 Install Argo Image Updater via Helm
    - Add Argo Helm repository if not already added
    - Install Argo Image Updater in argocd namespace
    - _Requirements: 5.1_
  
  - [ ] 16.2 Configure Image Updater for ECR
    - Create secret with Git credentials for write-back
    - Configure Image Updater to monitor ECR repository
    - _Requirements: 5.1, 5.4_
  
  - [ ] 16.3 Add Image Updater annotations to ArgoCD Application
    - Update argocd/application.yaml with image-list annotation
    - Add update-strategy annotation (latest)
    - Add write-back-method annotation (git)
    - Apply updated application manifest
    - _Requirements: 5.2, 5.3, 5.4_
  
  - [ ] 16.4 Test Image Updater flow
    - Push new image to ECR via Jenkins pipeline
    - Wait for Image Updater to detect new image
    - Verify Git repository updated with new image tag
    - Verify ArgoCD synced and deployed new version
    - _Requirements: 5.2, 5.3, 5.4, 5.5_

- [x] 17. Install and configure External Secrets Operator



  - [x] 17.1 Create IAM role for ESO service account


    - Create IAM policy with Secrets Manager read permissions (secretsmanager:GetSecretValue, secretsmanager:DescribeSecret)
    - Create IAM role with trust policy for EKS OIDC provider
    - Attach policy to role
    - _Requirements: 6.2_
  
  - [x] 17.2 Install External Secrets Operator via Helm


    - Create external-secrets-system namespace
    - Add External Secrets Helm repository
    - Install ESO using Helm
    - _Requirements: 6.1_
  

  - [x] 17.3 Create service account with IAM role annotation


    - Create service account in app namespace with IAM role annotation
    - _Requirements: 6.2_

  
  - [x] 17.4 Create SecretStore resource

    - Create application/secretstore.yaml pointing to AWS Secrets Manager
    - Configure AWS region and IRSA authentication
    - Apply SecretStore to app namespace
    - _Requirements: 6.3_
  
  - [x] 17.5 Create ExternalSecret for RDS credentials


    - Create application/externalsecret-rds.yaml
    - Map RDS secret from Secrets Manager to Kubernetes secret (rds-secret)
    - Map all required keys (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD)
    - Apply ExternalSecret to app namespace
    - _Requirements: 6.6_
  
  - [x] 17.6 Create ExternalSecret for Redis credentials


    - Create application/externalsecret-redis.yaml
    - Map Redis secret from Secrets Manager to Kubernetes secret (redis-secret)
    - Map all required keys (REDIS_HOST, REDIS_PORT)
    - Apply ExternalSecret to app namespace
    - _Requirements: 6.7_
  
  - [x] 17.7 Test External Secrets sync


    - Verify rds-secret and redis-secret created in app namespace
    - Check secret contents match AWS Secrets Manager
    - Verify application pods can read secrets
    - Update secret in AWS Secrets Manager and verify sync
    - _Requirements: 6.4, 6.5, 6.6, 6.7, 6.8_

- [ ] 18. Install and configure NGINX Ingress Controller
  - [ ] 18.1 Install NGINX Ingress Controller via Helm
    - Create ingress-nginx namespace
    - Add NGINX Ingress Helm repository
    - Create values.yaml for Ingress configuration (LoadBalancer service type)
    - Install NGINX Ingress using Helm
    - _Requirements: 7.1_
  
  - [ ] 18.2 Verify Load Balancer created
    - Check Ingress Controller service for external IP/hostname
    - Verify AWS Load Balancer created in AWS console
    - _Requirements: 7.5_

- [ ] 19. Install and configure cert-manager
  - [ ] 19.1 Install cert-manager via Helm
    - Create cert-manager namespace
    - Add Jetstack Helm repository
    - Install cert-manager with CRDs
    - _Requirements: 7.2_
  
  - [ ] 19.2 Create ClusterIssuer for Let's Encrypt
    - Create clusterissuer.yaml for Let's Encrypt production
    - Configure ACME server and email
    - Configure HTTP01 challenge solver
    - Apply ClusterIssuer
    - _Requirements: 7.6_

- [ ] 20. Create Ingress resource and test HTTPS access
  - [ ] 20.1 Create Ingress manifest
    - Create application/ingress.yaml
    - Configure host, TLS, and cert-manager annotations
    - Configure path routing to nodejs-app service
    - Add SSL redirect annotation
    - _Requirements: 7.3, 7.4_
  
  - [ ] 20.2 Apply Ingress and verify certificate
    - Apply Ingress manifest to app namespace
    - Wait for cert-manager to issue certificate
    - Verify certificate secret created
    - _Requirements: 7.7_
  
  - [ ] 20.3 Test HTTPS access
    - Configure DNS to point to Load Balancer
    - Access application via HTTPS
    - Verify certificate valid
    - Test application endpoints
    - _Requirements: 7.8_

- [ ] 21. Create comprehensive documentation
  - [ ] 21.1 Create architecture diagram
    - Create architecture diagram showing all components
    - Include data flow from developer to production
    - _Requirements: 8.1_
  
  - [ ] 21.2 Document setup instructions
    - Document prerequisites (AWS account, tools)
    - Document Terraform deployment steps
    - Document Jenkins setup steps
    - Document ArgoCD setup steps
    - Document ESO setup steps
    - Document Ingress setup steps
    - _Requirements: 8.2_
  
  - [ ] 21.3 Document CI/CD flow
    - Explain complete flow from code commit to deployment
    - Document Jenkins pipeline stages
    - Document ArgoCD sync process
    - Document Image Updater behavior
    - _Requirements: 8.4_
  
  - [ ] 21.4 Create troubleshooting guide
    - Document common issues and solutions
    - Include debugging commands
    - _Requirements: 8.5_
  
  - [ ] 21.5 Create README.md
    - Combine all documentation into comprehensive README
    - Include project overview, architecture, setup, and troubleshooting
    - _Requirements: 8.1, 8.2, 8.4, 8.5_
