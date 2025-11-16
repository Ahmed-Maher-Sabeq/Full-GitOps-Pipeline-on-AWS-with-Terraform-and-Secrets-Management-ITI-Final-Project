# AWS GitOps Pipeline - Architecture Diagram

## Diagram Structure for Eraser AI

### Layout Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                               │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                       │ │
│  │                                                            │ │
│  │  ┌──────────────────────┐  ┌──────────────────────────┐  │ │
│  │  │  PUBLIC SUBNETS      │  │  PRIVATE SUBNETS         │  │ │
│  │  │                      │  │                          │  │ │
│  │  │  • Internet Gateway  │  │  • EKS Cluster          │  │ │
│  │  │  • NAT Gateway       │  │    - Jenkins            │  │ │
│  │  │  • ALB               │  │    - ArgoCD             │  │ │
│  │  │                      │  │    - Image Updater      │  │ │
│  │  └──────────────────────┘  │    - External Secrets   │  │ │
│  │                             │    - nodejs-app (3 pods)│  │ │
│  │                             │                          │  │ │
│  │                             │  • RDS MySQL            │  │ │
│  │                             │  • Redis Cache          │  │ │
│  │                             └──────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Outside VPC:                                                    │
│  • ECR (Container Registry)                                      │
│  • Secrets Manager                                               │
└─────────────────────────────────────────────────────────────────┘

External:
• GitHub (Code & Helm Charts)
• Developer
• Internet Users
```

---

## Components by Location

### PUBLIC SUBNETS (Internet-Accessible)
1. **Internet Gateway** - Allows internet access
2. **NAT Gateway** - Provides internet for private subnets
3. **Application Load Balancer (ALB)** - Routes user traffic to apps

### PRIVATE SUBNETS (Secure, No Direct Internet)
1. **EKS Cluster** - Kubernetes with all applications:
   - Jenkins (builds images)
   - ArgoCD (deploys apps)
   - ArgoCD Image Updater (watches ECR)
   - External Secrets Operator (fetches secrets)
   - AWS Load Balancer Controller (manages ALB)
   - nodejs-app (3 pods)

2. **RDS MySQL** - Database
3. **ElastiCache Redis** - Cache

### OUTSIDE VPC (AWS Regional Services)
1. **ECR** - Stores Docker images
2. **Secrets Manager** - Stores credentials

### EXTERNAL (Outside AWS)
1. **GitHub** - Code and Helm charts
2. **Developer** - Pushes code
3. **Internet Users** - Access application

---

## Key Connections

### 1. CI/CD Flow (Green Arrows)
```
Developer 
  → GitHub (git push)
  → Jenkins (webhook)
  → ECR (push image: build-X)
  → Image Updater (checks every 2 min)
  → ArgoCD (update deployment)
  → nodejs-app pods (deploy new version)
```

### 2. User Traffic Flow (Purple Arrows)
```
Internet Users
  → Internet Gateway
  → ALB (public subnet)
  → nodejs-app pods (private subnet)
  → RDS MySQL (private subnet)
  → Redis Cache (private subnet)
```

### 3. Secrets Flow (Yellow Arrows)
```
Secrets Manager
  → External Secrets Operator (via IRSA)
  → Kubernetes Secrets
  → nodejs-app pods (environment variables)
```

### 4. GitOps Flow (Blue Arrows)
```
GitHub (Helm charts)
  → ArgoCD (pulls charts)
  → Kubernetes (applies manifests)
  → nodejs-app pods (deployed)
```

### 5. Internet Access from Private Subnet (Gray Arrows)
```
EKS Pods (private subnet)
  → NAT Gateway (public subnet)
  → Internet Gateway
  → Internet (for updates, ECR pulls)
```

---

## Detailed Connection List

**Connection 1:** Developer → GitHub
- Type: Git push
- Protocol: HTTPS
- Purpose: Push code changes

**Connection 2:** GitHub → Jenkins
- Type: Webhook
- Protocol: HTTPS
- Purpose: Trigger CI build

**Connection 3:** Jenkins → ECR
- Type: Docker push
- Protocol: HTTPS
- Purpose: Store built images (build-1, build-2, ...)
- Auth: IRSA (IAM role)

**Connection 4:** Image Updater → ECR
- Type: API calls (every 2 minutes)
- Protocol: HTTPS
- Purpose: Check for new images
- Auth: IRSA (IAM role)

**Connection 5:** Image Updater → ArgoCD Application
- Type: Kubernetes API
- Protocol: Internal
- Purpose: Update image tag in deployment

**Connection 6:** ArgoCD → GitHub
- Type: Git pull
- Protocol: HTTPS
- Purpose: Fetch Helm charts and manifests

**Connection 7:** ArgoCD → nodejs-app
- Type: Kubernetes API
- Protocol: Internal
- Purpose: Deploy/sync application

**Connection 8:** External Secrets → Secrets Manager
- Type: AWS API
- Protocol: HTTPS
- Purpose: Fetch DB credentials
- Auth: IRSA (IAM role)

**Connection 9:** External Secrets → nodejs-app
- Type: Kubernetes API
- Protocol: Internal
- Purpose: Create secrets in namespace

**Connection 10:** Internet Users → ALB
- Type: HTTP requests
- Protocol: HTTP/HTTPS
- Purpose: Access application

**Connection 11:** ALB → nodejs-app pods
- Type: HTTP proxy
- Protocol: HTTP
- Purpose: Route traffic to pods
- Path: ALB (public) → Private subnet

**Connection 12:** nodejs-app → RDS
- Type: Database queries
- Protocol: MySQL (port 3306)
- Purpose: Persistent data storage
- Security: Security group (EKS nodes only)

**Connection 13:** nodejs-app → Redis
- Type: Cache operations
- Protocol: Redis (port 6379)
- Purpose: Session/cache storage
- Security: Security group (EKS nodes only)

**Connection 14:** AWS LB Controller → ALB
- Type: AWS API
- Protocol: HTTPS
- Purpose: Create/manage load balancer
- Auth: IRSA (IAM role)

**Connection 15:** EKS Pods → NAT Gateway → Internet
- Type: Outbound traffic
- Protocol: HTTPS
- Purpose: Pull images, updates, external APIs
- Path: Private subnet → NAT (public) → Internet Gateway

---

## Network Security

### Public Subnet Security
- **Internet Gateway:** Allows inbound from internet to ALB only
- **NAT Gateway:** Allows outbound from private subnets
- **ALB:** Security group allows HTTP/HTTPS from internet

### Private Subnet Security
- **EKS Nodes:** No direct internet access (via NAT only)
- **RDS:** Security group allows port 3306 from EKS nodes only
- **Redis:** Security group allows port 6379 from EKS nodes only
- **Pods:** Use IRSA for AWS access (no credentials in containers)

### Traffic Rules
- **Inbound:** Internet → ALB → Pods (allowed)
- **Outbound:** Pods → NAT → Internet (allowed)
- **Internal:** Pods ↔ RDS/Redis (allowed via security groups)
- **Blocked:** Internet → RDS/Redis (blocked)
- **Blocked:** Internet → EKS Nodes (blocked)

---

## Visual Guide for Eraser AI

### Colors
- **Green:** Public subnets
- **Gray:** Private subnets
- **Orange:** AWS services (RDS, Redis, ECR, ALB)
- **Blue:** Kubernetes components
- **Yellow:** Secrets/security components

### Arrow Colors
- **Green:** CI/CD flow
- **Purple:** User traffic
- **Yellow:** Secrets flow
- **Blue:** GitOps flow
- **Gray:** Infrastructure/management

### Component Sizes
- **Large:** VPC, EKS Cluster
- **Medium:** Subnets, RDS, Redis, ECR
- **Small:** Individual pods, services

### Labels to Show
- Public Subnets: "PUBLIC (Internet-Accessible)"
- Private Subnets: "PRIVATE (Secure)"
- Each component: Name + purpose
- Each arrow: Number + action

---

## What Makes This Secure

✅ **Network Isolation:** Apps in private subnets, not internet-accessible
✅ **Database Security:** RDS/Redis only accessible from EKS
✅ **No Credentials:** IRSA provides temporary AWS access
✅ **Encrypted Secrets:** Secrets Manager encrypts all credentials
✅ **Controlled Access:** ALB is only entry point from internet

---

This architecture provides a secure, scalable, automated CI/CD pipeline with proper network segmentation.

