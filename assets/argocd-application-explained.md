# ArgoCD Application & Kubernetes Manifests Explained

## ArgoCD Application (application-no-annotations.yaml)

**Purpose:** ArgoCD Application resource that defines what to deploy, where to deploy it, and how to manage it.

### Key Sections

**Metadata:**
- Name: `nodejs-app`
- Namespace: `argocd` (where the Application resource lives)
- Finalizer: Ensures all deployed resources are deleted when Application is removed

**Source:**
- Git repository URL
- Branch: `main`
- Path: `k8s/helm-chart/nodejs-app` (Helm chart location)
- Helm parameters: Overrides `image.repository` and `image.tag` (updated by Image Updater)

**Destination:**
- Target cluster: Local cluster (`kubernetes.default.svc`)
- Target namespace: `nodejs-app`

**Sync Policy:**
- **Automated sync:** Deploys changes automatically
- **Prune:** Deletes resources removed from Git
- **Self-heal:** Reverts manual changes
- **CreateNamespace:** Creates namespace if missing
- **Retry:** 5 attempts with exponential backoff

---

## Kubernetes Manifests Deployed by This Application

When ArgoCD syncs this Application, it deploys 8 Kubernetes resources:

---

### 1. Namespace
```yaml
kind: Namespace
name: nodejs-app
```
- Creates the `nodejs-app` namespace
- Isolates application resources

---

### 2. ServiceAccount
```yaml
kind: ServiceAccount
name: nodejs-app-sa
annotations:
  eks.amazonaws.com/role-arn: <IAM_ROLE>
```
- Service account for the application pods
- Annotated with IAM role for IRSA
- Grants access to AWS Secrets Manager

---

### 3. SecretStore
```yaml
kind: SecretStore
name: aws-secrets-manager
provider:
  aws:
    service: SecretsManager
    region: us-east-1
    auth:
      jwt:
        serviceAccountRef:
          name: nodejs-app-sa
```
- Defines connection to AWS Secrets Manager
- Uses IRSA authentication via service account
- Used by ExternalSecrets to fetch secrets

---

### 4. ExternalSecret (RDS)
```yaml
kind: ExternalSecret
name: rds-external-secret
target:
  name: rds-secret
data:
  - secretKey: DB_HOST
    remoteRef:
      key: aws-gitops-pipeline-dev-rds-credentials
      property: host
  # + DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
```
- Fetches RDS credentials from AWS Secrets Manager
- Creates Kubernetes secret `rds-secret`
- Refreshes every 1 hour
- Maps AWS secret properties to Kubernetes secret keys

---

### 5. ExternalSecret (Redis)
```yaml
kind: ExternalSecret
name: redis-external-secret
target:
  name: redis-secret
data:
  - secretKey: REDIS_HOST
    remoteRef:
      key: aws-gitops-pipeline-dev-redis-credentials
      property: host
  # + REDIS_PORT
```
- Fetches Redis credentials from AWS Secrets Manager
- Creates Kubernetes secret `redis-secret`
- Refreshes every 1 hour

---

### 6. Deployment
```yaml
kind: Deployment
name: nodejs-app
replicas: 3
spec:
  template:
    spec:
      serviceAccountName: nodejs-app-sa
      containers:
      - name: nodejs-app
        image: <ECR_URL>:<TAG>
        envFrom:
        - secretRef:
            name: rds-secret
        - secretRef:
            name: redis-secret
        livenessProbe: /health
        readinessProbe: /health
        resources:
          requests: 100m CPU, 128Mi memory
          limits: 500m CPU, 512Mi memory
```
- Runs 3 replicas of the Node.js application
- Uses service account for IRSA
- Injects RDS and Redis secrets as environment variables
- Health checks on `/health` endpoint
- Resource limits for stability

---

### 7. Service
```yaml
kind: Service
name: nodejs-app
type: ClusterIP
ports:
  - port: 80
    targetPort: 3000
```
- ClusterIP service (internal only)
- Exposes pods on port 80
- Routes to container port 3000
- Used by Ingress for load balancing

---

### 8. Ingress
```yaml
kind: Ingress
name: nodejs-app
annotations:
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
  alb.ingress.kubernetes.io/healthcheck-path: /health
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            backend:
              service:
                name: nodejs-app
                port: 80
```
- Creates AWS Application Load Balancer
- Internet-facing (public access)
- Routes traffic to Service
- Health checks on `/health`
- Managed by AWS Load Balancer Controller

---

## Deployment Flow

```
1. Apply application-no-annotations.yaml to ArgoCD
   ↓
2. ArgoCD reads Git repo (k8s/helm-chart/nodejs-app)
   ↓
3. Renders Helm chart with parameters
   ↓
4. Deploys 8 Kubernetes resources:
   - Namespace
   - ServiceAccount (with IRSA)
   - SecretStore (ESO config)
   - ExternalSecret (RDS)
   - ExternalSecret (Redis)
   - Deployment (3 pods)
   - Service (ClusterIP)
   - Ingress (ALB)
   ↓
5. External Secrets Operator:
   - Fetches secrets from AWS Secrets Manager
   - Creates rds-secret and redis-secret
   ↓
6. Pods start:
   - Mount secrets as environment variables
   - Connect to RDS and Redis
   ↓
7. AWS LB Controller:
   - Creates Application Load Balancer
   - Configures target groups
   - Routes traffic to pods
   ↓
8. Application accessible via ALB URL
```

---

## Key Features

✅ **GitOps:** All configuration in Git  
✅ **Automated:** Self-healing and auto-sync  
✅ **Secure:** IRSA for AWS access, secrets from Secrets Manager  
✅ **Scalable:** 3 replicas with resource limits  
✅ **Observable:** Health checks and probes  
✅ **Production-ready:** Load balancer, secrets management, namespace isolation
