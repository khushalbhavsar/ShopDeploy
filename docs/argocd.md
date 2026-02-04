# 🚀 ArgoCD Setup Guide - ShopDeploy Project

Complete guide for setting up ArgoCD GitOps deployment for the ShopDeploy E-Commerce Platform.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Install ArgoCD on Kubernetes](#step-1-install-argocd-on-kubernetes)
4. [Access ArgoCD](#step-2-access-argocd)
5. [Login to ArgoCD](#step-3-login-to-argocd)
6. [Create ArgoCD Project](#step-4-create-argocd-project)
7. [Deploy Applications](#step-5-deploy-applications)
8. [Verify Deployment](#step-6-verify-deployment)
9. [Jenkins GitOps Integration](#step-7-jenkins-gitops-integration)
10. [Useful Commands](#useful-commands)
11. [Troubleshooting](#troubleshooting)
12. [Architecture](#architecture)

---

## Overview

### What is ArgoCD?

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of applications by monitoring Git repositories and syncing changes to Kubernetes clusters.

### GitOps Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Developer │────▶│  CI Pipeline│────▶│   GitOps    │────▶│   ArgoCD    │
│   Commits   │     │ Build Image │     │  Update Repo│     │  Auto-Sync  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                           │                   │                   │
                           ▼                   ▼                   ▼
                    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
                    │  Push to    │     │ Update Helm │     │  Deploy to  │
                    │    ECR      │     │   Values    │     │ Kubernetes  │
                    └─────────────┘     └─────────────┘     └─────────────┘
```

### Project Structure

```
ShopDeploy/
├── argocd/
│   ├── applications/
│   │   ├── dev/
│   │   │   ├── backend.yaml
│   │   │   └── frontend.yaml
│   │   ├── staging/
│   │   │   ├── backend.yaml
│   │   │   └── frontend.yaml
│   │   └── prod/
│   │       ├── backend.yaml
│   │       └── frontend.yaml
│   ├── applicationsets/
│   │   └── all-environments.yaml
│   ├── projects/
│   │   └── shopdeploy-project.yaml
│   └── notifications/
│       ├── notifications-cm.yaml
│       └── notifications-secret.yaml
├── gitops/
│   ├── dev/
│   │   ├── backend-values.yaml
│   │   └── frontend-values.yaml
│   ├── staging/
│   │   ├── backend-values.yaml
│   │   └── frontend-values.yaml
│   └── prod/
│       ├── backend-values.yaml
│       └── frontend-values.yaml
└── helm/
    ├── backend/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    └── frontend/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
```

### Folder Differences

| Folder | Purpose |
|--------|---------|
| `argocd/` | ArgoCD Application manifests (tells ArgoCD WHAT to deploy) |
| `gitops/` | Environment-specific Helm values (tells ArgoCD HOW to deploy) |
| `helm/` | Helm chart templates (the actual K8s resources) |

---

## Prerequisites

Before starting, ensure you have:

- ✅ Kubernetes cluster running (EKS, GKE, AKS, or local)
- ✅ `kubectl` configured to access your cluster
- ✅ Helm 3.x installed
- ✅ Git repository with Helm charts
- ✅ ECR/Docker registry with images

### Verify Prerequisites

```bash
# Check kubectl connection
kubectl cluster-info

# Check kubectl version
kubectl version --client

# Check Helm version
helm version
```

---

## Step 1: Install ArgoCD on Kubernetes

### Option A: Quick Install (Recommended for Dev)

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
```

### Option B: Install with Helm (Recommended for Production)

```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD with custom values
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --set server.extraArgs={--insecure}
```

### Verify ArgoCD Installation

```bash
# Check all ArgoCD pods are running
kubectl get pods -n argocd

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# argocd-application-controller-xxx     1/1     Running   0          2m
# argocd-dex-server-xxx                 1/1     Running   0          2m
# argocd-redis-xxx                      1/1     Running   0          2m
# argocd-repo-server-xxx                1/1     Running   0          2m
# argocd-server-xxx                     1/1     Running   0          2m

# Check ArgoCD services
kubectl get svc -n argocd
```

---

## Step 2: Access ArgoCD

### Option A: Port Forward (Development/Testing)

```bash
# Port forward ArgoCD server to localhost:8080
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access ArgoCD UI at: https://localhost:8080
```

### Option B: LoadBalancer (Production)

```bash
# Patch ArgoCD server to use LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get the external IP/URL
kubectl get svc argocd-server -n argocd

# Wait for EXTERNAL-IP to be assigned
# Access ArgoCD UI at: https://<EXTERNAL-IP>
```

### Option C: Ingress (Production with Domain)

```bash
# Create Ingress for ArgoCD
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: argocd.shopdeploy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
EOF
```

---

## Step 3: Login to ArgoCD

### Get Initial Admin Password

```bash
# Get the initial admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 --decode && echo
```

**Default Credentials:**
- **Username:** `admin`
- **Password:** *(output from the command above)*

### Install ArgoCD CLI (Optional but Recommended)

```bash
# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# macOS
brew install argocd

# Windows (using Chocolatey)
choco install argocd-cli

# Windows (using Scoop)
scoop install argocd
```

### Login via CLI

```bash
# Login to ArgoCD (replace with your server URL)
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure

# Or with port-forward running
argocd login localhost:8080 --insecure

# Change admin password (recommended)
argocd account update-password
```

### Login via UI

1. Open browser: `https://localhost:8080` (or your ArgoCD URL)
2. Enter username: `admin`
3. Enter password: *(from the command above)*
4. Click **Sign In**

---

## Step 4: Create ArgoCD Project

### Option A: Apply Project Manifest (Recommended)

```bash
# Apply the ArgoCD project
kubectl apply -f argocd/projects/shopdeploy-project.yaml
```

**Project Manifest Content** (`argocd/projects/shopdeploy-project.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: shopdeploy
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: ShopDeploy E-Commerce Platform

  # Source repositories
  sourceRepos:
    - 'https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git'

  # Destination clusters and namespaces
  destinations:
    - namespace: shopdeploy-dev
      server: https://kubernetes.default.svc
    - namespace: shopdeploy-staging
      server: https://kubernetes.default.svc
    - namespace: shopdeploy-prod
      server: https://kubernetes.default.svc

  # Allowed cluster resources
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace

  # Allowed namespace resources
  namespaceResourceWhitelist:
    - group: ''
      kind: '*'
    - group: 'apps'
      kind: '*'
    - group: 'networking.k8s.io'
      kind: '*'
    - group: 'autoscaling'
      kind: '*'

  # Roles
  roles:
    - name: developer
      description: Developer access
      policies:
        - p, proj:shopdeploy:developer, applications, get, shopdeploy/*, allow
        - p, proj:shopdeploy:developer, applications, sync, shopdeploy/*, allow
      groups:
        - developers

    - name: admin
      description: Admin access
      policies:
        - p, proj:shopdeploy:admin, applications, *, shopdeploy/*, allow
      groups:
        - admins
```

### Option B: Create via ArgoCD CLI

```bash
# Create project via CLI
argocd proj create shopdeploy \
  --description "ShopDeploy E-Commerce Platform" \
  --dest https://kubernetes.default.svc,shopdeploy-dev \
  --dest https://kubernetes.default.svc,shopdeploy-staging \
  --dest https://kubernetes.default.svc,shopdeploy-prod \
  --src https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git

# Add allowed resources
argocd proj allow-cluster-resource shopdeploy '' Namespace
argocd proj allow-namespace-resource shopdeploy '' '*'
argocd proj allow-namespace-resource shopdeploy apps '*'
```

### Option C: Create via ArgoCD UI

1. Login to ArgoCD UI
2. Go to **Settings** (gear icon) → **Projects**
3. Click **+ New Project**
4. Fill in:
   - **Name:** `shopdeploy`
   - **Description:** `ShopDeploy E-Commerce Platform`
5. **Source Repositories:** Add `https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git`
6. **Destinations:** Add:
   - Server: `https://kubernetes.default.svc`, Namespace: `shopdeploy-dev`
   - Server: `https://kubernetes.default.svc`, Namespace: `shopdeploy-staging`
   - Server: `https://kubernetes.default.svc`, Namespace: `shopdeploy-prod`
7. Click **Create**

### Verify Project Created

```bash
# List all projects
argocd proj list

# Get project details
argocd proj get shopdeploy
```

---

## Step 5: Deploy Applications

### Create Kubernetes Namespaces First

```bash
# Create namespaces for all environments
kubectl create namespace shopdeploy-dev
kubectl create namespace shopdeploy-staging
kubectl create namespace shopdeploy-prod

# Verify namespaces
kubectl get namespaces | grep shopdeploy
```

### Option A: Apply Application Manifests (Recommended)

```bash
# Apply all applications at once
kubectl apply -f argocd/projects/
kubectl apply -f argocd/applications/dev/
kubectl apply -f argocd/applications/staging/
kubectl apply -f argocd/applications/prod/

# Or apply individually
kubectl apply -f argocd/applications/dev/backend.yaml
kubectl apply -f argocd/applications/dev/frontend.yaml
```

**Application Manifest Example** (`argocd/applications/dev/backend.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: shopdeploy-backend-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: shopdeploy
  
  source:
    repoURL: https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git
    targetRevision: main
    path: helm/backend
    helm:
      valueFiles:
        - ../../gitops/dev/backend-values.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: shopdeploy-dev

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
```

### Option B: Create via ArgoCD CLI

```bash
# Create dev backend application
argocd app create shopdeploy-backend-dev \
  --repo https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git \
  --path helm/backend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace shopdeploy-dev \
  --project shopdeploy \
  --sync-policy automated \
  --auto-prune \
  --self-heal \
  --helm-set-file values=../../gitops/dev/backend-values.yaml

# Create dev frontend application
argocd app create shopdeploy-frontend-dev \
  --repo https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git \
  --path helm/frontend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace shopdeploy-dev \
  --project shopdeploy \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

### Option C: Create via ArgoCD UI

1. Click **+ New App**
2. Fill in:
   - **Application Name:** `shopdeploy-backend-dev`
   - **Project:** `shopdeploy`
   - **Sync Policy:** `Automatic`
   - **Repository URL:** `https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git`
   - **Revision:** `main`
   - **Path:** `helm/backend`
   - **Cluster URL:** `https://kubernetes.default.svc`
   - **Namespace:** `shopdeploy-dev`
3. Click **Create**

---

## Step 6: Verify Deployment

### Check Application Status

```bash
# List all applications
argocd app list

# Get detailed status of an application
argocd app get shopdeploy-backend-dev

# Check sync status
argocd app get shopdeploy-backend-dev -o json | jq '.status.sync.status'

# Check health status
argocd app get shopdeploy-backend-dev -o json | jq '.status.health.status'
```

### Sync Applications Manually (if needed)

```bash
# Sync a specific application
argocd app sync shopdeploy-backend-dev

# Sync with prune (remove resources not in Git)
argocd app sync shopdeploy-backend-dev --prune

# Sync all applications in project
argocd app sync -l project=shopdeploy
```

### Check Kubernetes Resources

```bash
# Check pods in dev namespace
kubectl get pods -n shopdeploy-dev

# Check all resources in dev namespace
kubectl get all -n shopdeploy-dev

# Check deployments
kubectl get deployments -n shopdeploy-dev

# Check services
kubectl get svc -n shopdeploy-dev

# Check logs
kubectl logs -n shopdeploy-dev -l app=shopdeploy-backend
```

### View in ArgoCD UI

1. Open ArgoCD UI
2. Click on application name (e.g., `shopdeploy-backend-dev`)
3. View:
   - **Sync Status:** Should be "Synced"
   - **Health Status:** Should be "Healthy"
   - **Resource Tree:** Visual view of all K8s resources

---

## Step 7: Jenkins GitOps Integration

### How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Jenkins CI │────▶│ Update      │────▶│   ArgoCD    │
│  Pipeline   │     │ GitOps Repo │     │  Auto-Sync  │
└─────────────┘     └─────────────┘     └─────────────┘
```

1. **CI Pipeline** builds and pushes Docker image to ECR
2. **CI Pipeline** updates `gitops/{env}/backend-values.yaml` with new image tag
3. **ArgoCD** detects changes in Git and auto-syncs to Kubernetes

### Jenkins Pipeline for GitOps

Use the `Jenkinsfile-gitops` pipeline:

```groovy
// Key stage that updates GitOps
stage('Update GitOps') {
    steps {
        sh """
            # Update image tag in values file
            sed -i 's|tag:.*|tag: "${IMAGE_TAG}"|g' gitops/${ENVIRONMENT}/backend-values.yaml
            
            # Commit and push
            git add gitops/${ENVIRONMENT}/
            git commit -m "Deploy ${IMAGE_TAG} to ${ENVIRONMENT}"
            git push origin main
        """
    }
}
```

### Create Jenkins GitOps Pipeline

1. Go to Jenkins → **New Item**
2. Name: `ShopDeploy-GitOps`
3. Type: **Pipeline**
4. Configure:
   - **Pipeline script from SCM:** Git
   - **Repository URL:** `https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git`
   - **Script Path:** `ci-cd/Jenkinsfile-gitops`

### Required Jenkins Credentials

| Credential ID | Type | Description |
|---------------|------|-------------|
| `github-credentials` | Username/Password | GitHub PAT for push |
| `aws-credentials` | AWS Credentials | For ECR access |
| `aws-account-id` | Secret text | AWS Account ID |

---

## Useful Commands

### ArgoCD CLI Commands

```bash
# Login
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>

# List applications
argocd app list

# Get application details
argocd app get <APP_NAME>

# Sync application
argocd app sync <APP_NAME>

# Delete application
argocd app delete <APP_NAME>

# Rollback application
argocd app rollback <APP_NAME> <REVISION>

# View application history
argocd app history <APP_NAME>

# Refresh application (check for changes)
argocd app get <APP_NAME> --refresh

# Hard refresh (clear cache)
argocd app get <APP_NAME> --hard-refresh
```

### Project Commands

```bash
# List projects
argocd proj list

# Get project details
argocd proj get <PROJECT_NAME>

# Delete project
argocd proj delete <PROJECT_NAME>

# Add source repo to project
argocd proj add-source <PROJECT> <REPO_URL>

# Add destination to project
argocd proj add-destination <PROJECT> <SERVER> <NAMESPACE>
```

### Kubectl Commands for ArgoCD

```bash
# Get ArgoCD pods
kubectl get pods -n argocd

# Get ArgoCD applications (CRDs)
kubectl get applications -n argocd

# Describe application
kubectl describe application <APP_NAME> -n argocd

# Get application YAML
kubectl get application <APP_NAME> -n argocd -o yaml

# Delete application
kubectl delete application <APP_NAME> -n argocd
```

---

## Troubleshooting

### Common Issues

#### 1. Application Stuck in "Progressing"

```bash
# Check application events
kubectl describe application <APP_NAME> -n argocd

# Check pod status
kubectl get pods -n <APP_NAMESPACE>

# Check pod logs
kubectl logs -n <APP_NAMESPACE> <POD_NAME>

# Check pod events
kubectl describe pod -n <APP_NAMESPACE> <POD_NAME>
```

#### 2. Application "OutOfSync"

```bash
# Force sync
argocd app sync <APP_NAME> --force

# Sync with prune
argocd app sync <APP_NAME> --prune

# Hard refresh and sync
argocd app get <APP_NAME> --hard-refresh
argocd app sync <APP_NAME>
```

#### 3. "Repository not accessible"

```bash
# Add repository with credentials
argocd repo add https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform.git \
  --username <USERNAME> \
  --password <PAT_TOKEN>

# List repositories
argocd repo list
```

#### 4. "Namespace does not exist"

```bash
# Create namespace manually
kubectl create namespace <NAMESPACE>

# Or enable auto-create in application
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

#### 5. ArgoCD Server Not Accessible

```bash
# Check argocd-server pod
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Restart argocd-server
kubectl rollout restart deployment argocd-server -n argocd
```

#### 6. Reset Admin Password

```bash
# Generate new password hash
ARGOCD_PASSWORD=$(htpasswd -nbBC 10 "" "newpassword" | tr -d ':\n' | sed 's/$2y/$2a/')

# Patch the secret
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "'$ARGOCD_PASSWORD'",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
```

---

## Architecture

### Complete GitOps Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GITOPS WORKFLOW                                │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Developer  │────▶│   GitHub    │────▶│  Jenkins CI │
│  git push   │     │    Repo     │     │  Triggered  │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           JENKINS CI PIPELINE                            │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │  Lint   │▶│  Test   │▶│  Build  │▶│  Push   │▶│ Update  │           │
│  │  Code   │ │  Code   │ │  Docker │ │  ECR    │ │ GitOps  │           │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │
└─────────────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         GITOPS REPOSITORY                                │
│                                                                          │
│  gitops/                                                                 │
│  ├── dev/                                                                │
│  │   ├── backend-values.yaml    ◄── Updated with new image tag         │
│  │   └── frontend-values.yaml   ◄── Updated with new image tag         │
│  ├── staging/                                                            │
│  └── prod/                                                               │
└─────────────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              ARGOCD                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Watches Git Repository for Changes (every 3 minutes or webhook) │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                               │                                          │
│                               ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              Auto-Sync to Kubernetes Cluster                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         KUBERNETES CLUSTER                               │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │  shopdeploy-dev │  │shopdeploy-staging│  │ shopdeploy-prod │         │
│  │    Namespace    │  │    Namespace     │  │    Namespace    │         │
│  │                 │  │                  │  │                 │         │
│  │  ┌───────────┐  │  │  ┌───────────┐   │  │  ┌───────────┐  │         │
│  │  │  Backend  │  │  │  │  Backend  │   │  │  │  Backend  │  │         │
│  │  │  Pods     │  │  │  │  Pods     │   │  │  │  Pods     │  │         │
│  │  └───────────┘  │  │  └───────────┘   │  │  └───────────┘  │         │
│  │  ┌───────────┐  │  │  ┌───────────┐   │  │  ┌───────────┐  │         │
│  │  │ Frontend  │  │  │  │ Frontend  │   │  │  │ Frontend  │  │         │
│  │  │  Pods     │  │  │  │  Pods     │   │  │  │  Pods     │  │         │
│  │  └───────────┘  │  │  └───────────┘   │  │  └───────────┘  │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Environment Promotion Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     DEV     │────▶│   STAGING   │────▶│    PROD     │
│  🟢 Auto    │     │  🟡 Auto    │     │  🔴 Manual  │
│  Deploy     │     │  Deploy     │     │  Approval   │
└─────────────┘     └─────────────┘     └─────────────┘
```

---

## Quick Reference

### URLs and Endpoints

| Service | URL |
|---------|-----|
| ArgoCD UI | `https://localhost:8080` or `https://argocd.shopdeploy.com` |
| GitHub Repo | `https://github.com/khushalbhavsar/ShopDeploy-Cloud-Native-DevOps-Platform` |

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| ArgoCD | `admin` | Run: `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" \| base64 --decode` |

### Namespaces

| Environment | Namespace |
|-------------|-----------|
| Development | `shopdeploy-dev` |
| Staging | `shopdeploy-staging` |
| Production | `shopdeploy-prod` |

### Applications

| Application | Environment | Namespace |
|-------------|-------------|-----------|
| `shopdeploy-backend-dev` | Dev | `shopdeploy-dev` |
| `shopdeploy-frontend-dev` | Dev | `shopdeploy-dev` |
| `shopdeploy-backend-staging` | Staging | `shopdeploy-staging` |
| `shopdeploy-frontend-staging` | Staging | `shopdeploy-staging` |
| `shopdeploy-backend-prod` | Prod | `shopdeploy-prod` |
| `shopdeploy-frontend-prod` | Prod | `shopdeploy-prod` |

---

## Next Steps

1. ✅ Install ArgoCD on your cluster
2. ✅ Login and change admin password
3. ✅ Create the ShopDeploy project
4. ✅ Deploy applications to dev environment
5. ⬜ Set up ArgoCD notifications (Slack/Email)
6. ⬜ Configure RBAC for team access
7. ⬜ Set up ArgoCD Image Updater for automatic image updates
8. ⬜ Configure production approval workflows

---

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD GitHub](https://github.com/argoproj/argo-cd)
- [GitOps Principles](https://www.gitops.tech/)
- [Helm Documentation](https://helm.sh/docs/)

---

*Last Updated: February 2026*
*Project: ShopDeploy E-Commerce Platform*

