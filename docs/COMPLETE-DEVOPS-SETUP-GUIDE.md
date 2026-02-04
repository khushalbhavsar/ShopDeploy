# 🚀 COMPLETE SHOPDEPLOY DEVOPS SETUP

**Start → End with Commands**

This is the complete, step-by-step guide to set up the entire ShopDeploy DevOps infrastructure from scratch.

---

## 📋 Table of Contents

- [Phase 0: Architecture Overview](#-phase-0--architecture-overview)
- [Phase 1: EC2 Setup (DevOps Server)](#-phase-1--ec2-setup-devops-server)
- [Phase 2: Install AWS CLI](#-phase-2--install-aws-cli)
- [Phase 3: Install kubectl](#-phase-3--install-kubectl)
- [Phase 4: Connect to EKS](#-phase-4--connect-to-eks)
- [Phase 5: Install Helm](#-phase-5--install-helm)
- [Phase 6: Install ArgoCD](#-phase-6--install-argocd)
- [Phase 7: Expose ArgoCD](#-phase-7--expose-argocd-loadbalancer)
- [Phase 8: Create ArgoCD Project](#-phase-8--create-argocd-project)
- [Phase 9: Create Applications](#-phase-9--create-applications)
- [Phase 10: Enable Auto Sync](#-phase-10--enable-auto-sync)
- [Phase 11: Jenkins Role](#-phase-11--jenkins-role-after-gitops)
- [Phase 12: GitOps Pipeline Flow](#-phase-12--gitops-pipeline-flow)
- [Phase 13: Verify Deployment](#-phase-13--verify-deployment)
- [Phase 14: Monitoring](#-phase-14--monitoring)
- [Phase 15: Security](#-phase-15--security)
- [Phase 16: Next Level](#-phase-16--next-level-argocd-image-updater)

---

# ✅ PHASE 0 — Architecture Overview

Your stack is now **VERY ADVANCED**:

```
Developer → GitHub → Jenkins CI → ECR → GitOps Repo → ArgoCD → EKS → Users
```

You are no longer doing basic CI/CD.

You are doing:

👉 **CI + GitOps Deployment Model**

This is what modern companies use.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SHOPDEPLOY DEVOPS ARCHITECTURE                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│Developer │───▶│  GitHub  │───▶│ Jenkins  │───▶│   ECR    │───▶│  GitOps  │
│  Code    │    │   Repo   │    │    CI    │    │  Images  │    │   Repo   │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
                                                                      │
                                                                      ▼
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│   User   │◀───│   ALB    │◀───│   EKS    │◀───│  ArgoCD  │◀───│  Detect  │
│  Access  │    │ Ingress  │    │ Cluster  │    │  Deploy  │    │  Change  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
```

---

# 🔥 PHASE 1 — EC2 Setup (DevOps Server)

## Update OS

```bash
sudo yum update -y
```

---

## Install Docker

```bash
# Install Docker
sudo yum install docker -y

# Start Docker service
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker

# Add user to docker group (no sudo needed for docker commands)
sudo usermod -aG docker ec2-user
```

⚠️ **IMPORTANT:** Re-login after adding user to docker group!

```bash
# Logout and login again, then verify
exit
# SSH back in

# Check Docker version
docker --version
```

Expected output: `Docker version 20.x.x` or higher

---

## Install Git

```bash
sudo yum install git -y
git --version
```

Expected output: `git version 2.x.x`

---

# 🔥 PHASE 2 — Install AWS CLI

```bash
# Download AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Unzip
unzip awscliv2.zip

# Install
sudo ./aws/install

# Verify
aws --version
```

## Configure AWS CLI

```bash
aws configure
```

Enter your credentials:

```
AWS Access Key ID: YOUR_ACCESS_KEY
AWS Secret Access Key: YOUR_SECRET_KEY
Default region name: us-east-1
Default output format: json
```

### Verify Configuration

```bash
aws sts get-caller-identity
```

Should return your AWS account info.

---

# 🔥 PHASE 3 — Install kubectl

**This is VERY IMPORTANT for managing Kubernetes!**

```bash
# Download kubectl for EKS 1.29
curl -o kubectl https://amazon-eks.s3.us-east-1.amazonaws.com/1.29.0/2024-01-04/bin/linux/amd64/kubectl

# Make executable
chmod +x kubectl

# Move to PATH
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client
```

Expected output: `Client Version: v1.29.x`

---

# 🔥 PHASE 4 — Connect to EKS

## 🚨 MOST IMPORTANT COMMAND

This connects your kubectl to the EKS cluster:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name shopdeploy-prod-eks
```

## Verify Connection

```bash
kubectl get nodes
```

✅ If nodes appear → cluster connected successfully!

Expected output:

```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.ec2.internal   Ready    <none>   1d    v1.29.x
ip-10-0-2-xxx.ec2.internal   Ready    <none>   1d    v1.29.x
```

### Additional Verification

```bash
# Check cluster info
kubectl cluster-info

# Check all namespaces
kubectl get namespaces

# Check all pods in all namespaces
kubectl get pods -A
```

---

# 🔥 PHASE 5 — Install Helm

Helm is the package manager for Kubernetes.

```bash
# Install Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

Expected output: `version.BuildInfo{Version:"v3.x.x"}`

---

# 🚨 PRE-ARGOCD CHECKLIST

Before installing ArgoCD, verify your cluster is healthy:

```bash
# Check all pods are running
kubectl get pods -A

# Check all services
kubectl get svc -A

# Check nodes are ready
kubectl get nodes
```

All pods should be `Running` or `Completed`.
All nodes should be `Ready`.

---

# 🔥 PHASE 6 — Install ArgoCD

## ✅ Step 1: Create Namespace

```bash
kubectl create namespace argocd
```

## ✅ Step 2: Install ArgoCD

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## ✅ Step 3: Wait and Verify

Wait 2-3 minutes for pods to start.

```bash
# Check ArgoCD pods
kubectl get pods -n argocd
```

**All pods must be `Running`:**

```
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-xxx     1/1     Running   0          2m
argocd-dex-server-xxx                 1/1     Running   0          2m
argocd-redis-xxx                      1/1     Running   0          2m
argocd-repo-server-xxx                1/1     Running   0          2m
argocd-server-xxx                     1/1     Running   0          2m
```

---

# 🔥 PHASE 7 — Expose ArgoCD (LoadBalancer)

## Patch ArgoCD Server to LoadBalancer

```bash
kubectl patch svc argocd-server \
  -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'
```

## Get External URL

```bash
kubectl get svc argocd-server -n argocd
```

Output:

```
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP                              PORT(S)
argocd-server   LoadBalancer   10.100.x.x     xxx.us-east-1.elb.amazonaws.com         443:xxxxx/TCP
```

## Access ArgoCD UI

Open in browser:

```
https://EXTERNAL-IP
```

⚠️ Use the **EXTERNAL-IP** (ELB DNS), NOT EC2 IP!

---

# 🔐 Get ArgoCD Login Credentials

## Username

```
admin
```

## Password

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 --decode && echo
```

Copy the output — this is your password.

## Login

1. Open: `https://EXTERNAL-IP`
2. Username: `admin`
3. Password: (from command above)
4. Click **Sign In**

---

# 🔥 PHASE 8 — Create ArgoCD Project

## Apply Project YAML

```bash
kubectl apply -f argocd/projects/shopdeploy-project.yaml
```

## Verify Project Created

```bash
kubectl get appprojects -n argocd
```

Expected output:

```
NAME         AGE
default      10m
shopdeploy   5s
```

---

# 🔥 PHASE 9 — Create Applications

## Create Namespaces First

```bash
kubectl create namespace shopdeploy-dev
kubectl create namespace shopdeploy-staging
kubectl create namespace shopdeploy-prod
```

## Deploy DEV Environment First

```bash
kubectl apply -f argocd/applications/dev/
```

## Deploy All Environments

```bash
# Apply all applications
kubectl apply -f argocd/applications/dev/
kubectl apply -f argocd/applications/staging/
kubectl apply -f argocd/applications/prod/
```

## Verify Applications

```bash
kubectl get applications -n argocd
```

Expected output:

```
NAME                        SYNC STATUS   HEALTH STATUS
shopdeploy-backend-dev      Synced        Healthy
shopdeploy-frontend-dev     Synced        Healthy
shopdeploy-backend-staging  Synced        Healthy
shopdeploy-frontend-staging Synced        Healthy
shopdeploy-backend-prod     OutOfSync     Missing
shopdeploy-frontend-prod    OutOfSync     Missing
```

## Sync from UI

1. Open ArgoCD UI
2. Click on application name
3. Click **SYNC** button
4. Click **SYNCHRONIZE**

---

# 🔥 PHASE 10 — Enable Auto Sync

## Why Auto Sync?

With Auto Sync enabled:

- 👉 No manual deploy needed
- 👉 No kubectl commands
- 👉 No Jenkins CD pipeline
- 👉 Git becomes the deployment trigger

## Enable in Application YAML

Your application YAML should have:

```yaml
spec:
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Auto-fix drift from desired state
    syncOptions:
      - CreateNamespace=true
```

## Verify Auto Sync is Working

1. Make a change to `gitops/dev/backend-values.yaml`
2. Push to Git
3. Watch ArgoCD UI — it will auto-sync within 3 minutes
4. Or manually refresh: Click app → **REFRESH**

---

# 🔥 PHASE 11 — Jenkins Role (After GitOps)

## What Jenkins Should Do Now

| ✅ DO | ❌ DON'T |
|-------|----------|
| Build Docker images | Deploy to Kubernetes |
| Run tests | Run kubectl commands |
| Run SonarQube scan | Manage deployments |
| Run Trivy security scan | Handle rollbacks |
| Push to ECR | |
| Update GitOps values | |

## New Architecture

**Before (Push-based):**
```
Jenkins CI → Jenkins CD → kubectl apply → Kubernetes
```

**After (Pull-based GitOps):**
```
Jenkins CI → Update Git → ArgoCD detects → Kubernetes
```

You are now using:

👉 **Pull-based deployment (GitOps)** — Senior-level architecture!

---

# 🔥 PHASE 12 — GitOps Pipeline Flow

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GITOPS DEPLOYMENT FLOW                           │
└─────────────────────────────────────────────────────────────────────────┘

  Developer pushes code
          │
          ▼
  ┌───────────────────┐
  │   GitHub Webhook  │
  │   Triggers Jenkins│
  └───────────────────┘
          │
          ▼
  ┌───────────────────┐
  │   Jenkins CI      │
  │   - Lint          │
  │   - Test          │
  │   - SonarQube     │
  │   - Build Docker  │
  │   - Trivy Scan    │
  │   - Push to ECR   │
  └───────────────────┘
          │
          ▼
  ┌───────────────────┐
  │   GitOps Pipeline │
  │   Updates:        │
  │   gitops/dev/     │
  │   backend-values  │
  │   .yaml           │
  └───────────────────┘
          │
          ▼
  ┌───────────────────┐
  │   Git Push        │
  │   to main branch  │
  └───────────────────┘
          │
          ▼
  ┌───────────────────┐
  │   ArgoCD Detects  │
  │   Change          │
  │   (within 3 min)  │
  └───────────────────┘
          │
          ▼
  ┌───────────────────┐
  │   Auto Deploy     │
  │   to EKS          │
  └───────────────────┘
          │
          ▼
  ┌───────────────────┐
  │   Application     │
  │   Running!        │
  └───────────────────┘
```

## Result

🎯 **ZERO manual work after git push!**

---

# 🔥 PHASE 13 — Verify Deployment

## Check Pods

```bash
# Dev environment
kubectl get pods -n shopdeploy-dev

# Staging environment
kubectl get pods -n shopdeploy-staging

# Production environment
kubectl get pods -n shopdeploy-prod
```

Expected output:

```
NAME                                    READY   STATUS    RESTARTS   AGE
shopdeploy-backend-xxx-xxx              1/1     Running   0          5m
shopdeploy-frontend-xxx-xxx             1/1     Running   0          5m
```

## Check Services

```bash
kubectl get svc -n shopdeploy-dev
```

## Access Application

### If LoadBalancer Service:

```bash
kubectl get svc -n shopdeploy-dev
# Copy EXTERNAL-IP
# Open: http://EXTERNAL-IP
```

### If ClusterIP Service:

```bash
# Port forward to localhost
kubectl port-forward svc/shopdeploy-frontend \
  -n shopdeploy-dev 8080:80

# Open: http://localhost:8080
```

## Check Logs

```bash
# Backend logs
kubectl logs -n shopdeploy-dev -l app=shopdeploy-backend

# Frontend logs
kubectl logs -n shopdeploy-dev -l app=shopdeploy-frontend
```

---

# 🔥 PHASE 14 — Monitoring

## Install Prometheus + Grafana Stack

```bash
# Add Helm repo
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

# Update repos
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

## Access Grafana

```bash
# Get Grafana password
kubectl get secret prometheus-grafana \
  -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 --decode && echo

# Port forward Grafana
kubectl port-forward svc/prometheus-grafana \
  -n monitoring 3000:80
```

Open: `http://localhost:3000`
- Username: `admin`
- Password: (from command above)

## Access Prometheus

```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus \
  -n monitoring 9090:9090
```

Open: `http://localhost:9090`

---

# 🔥 PHASE 15 — Security

## What You Should Have

| Tool | Purpose | Status |
|------|---------|--------|
| ✅ Trivy | Container security scanning | Implemented |
| ✅ SonarQube | Code quality analysis | Implemented |
| ✅ Network Policies | Pod-to-pod security | In K8s manifests |
| ✅ IAM Roles | AWS permissions | Terraform managed |
| ✅ Kubernetes Secrets | Sensitive data | In K8s manifests |
| ✅ HTTPS/TLS | Encrypted traffic | Via Ingress |

## Security Commands

```bash
# Check secrets
kubectl get secrets -n shopdeploy-dev

# Check network policies
kubectl get networkpolicies -n shopdeploy-dev

# Check service accounts
kubectl get serviceaccounts -n shopdeploy-dev
```

---

# 🔥 PHASE 16 — Next Level (ArgoCD Image Updater)

## What is ArgoCD Image Updater?

Automatically updates image tags in Git when new images are pushed to ECR.

## Flow Without Image Updater

```
CI → Build Image → Push ECR → GitOps Pipeline updates tag → ArgoCD deploys
```

## Flow With Image Updater

```
CI → Build Image → Push ECR → Image Updater detects → Updates Git → ArgoCD deploys
```

👉 **No GitOps pipeline needed!**

## Install ArgoCD Image Updater

```bash
# Install Image Updater
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Verify
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater
```

## Configure Application for Image Updater

Add annotations to your ArgoCD Application:

```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: backend=YOUR_ECR/shopdeploy-backend
    argocd-image-updater.argoproj.io/backend.update-strategy: newest-build
    argocd-image-updater.argoproj.io/write-back-method: git
```

---

# 📋 Quick Reference

## All Commands in Order

```bash
# 1. Update OS
sudo yum update -y

# 2. Install Docker
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# 3. Install Git
sudo yum install git -y

# 4. Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws configure

# 5. Install kubectl
curl -o kubectl https://amazon-eks.s3.us-east-1.amazonaws.com/1.29.0/2024-01-04/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 6. Connect to EKS
aws eks update-kubeconfig --region us-east-1 --name shopdeploy-prod-eks

# 7. Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 8. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 9. Expose ArgoCD
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# 10. Get ArgoCD password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode

# 11. Create project
kubectl apply -f argocd/projects/shopdeploy-project.yaml

# 12. Deploy applications
kubectl apply -f argocd/applications/dev/
kubectl apply -f argocd/applications/staging/
kubectl apply -f argocd/applications/prod/

# 13. Verify
kubectl get applications -n argocd
kubectl get pods -n shopdeploy-dev
```

---

# ✅ Checklist

| Phase | Task | Status |
|-------|------|--------|
| 0 | Understand architecture | ⬜ |
| 1 | EC2 setup (Docker, Git) | ⬜ |
| 2 | AWS CLI installed | ⬜ |
| 3 | kubectl installed | ⬜ |
| 4 | Connected to EKS | ⬜ |
| 5 | Helm installed | ⬜ |
| 6 | ArgoCD installed | ⬜ |
| 7 | ArgoCD exposed | ⬜ |
| 8 | ArgoCD project created | ⬜ |
| 9 | Applications deployed | ⬜ |
| 10 | Auto-sync enabled | ⬜ |
| 11 | Jenkins CI-only mode | ⬜ |
| 12 | GitOps flow working | ⬜ |
| 13 | Deployment verified | ⬜ |
| 14 | Monitoring setup | ⬜ |
| 15 | Security implemented | ⬜ |
| 16 | Image Updater (optional) | ⬜ |

---

# 🎉 Congratulations!

You now have a **production-grade DevOps setup**:

- ✅ Infrastructure as Code (Terraform)
- ✅ CI Pipeline (Jenkins)
- ✅ Container Registry (ECR)
- ✅ GitOps Deployment (ArgoCD)
- ✅ Kubernetes Orchestration (EKS)
- ✅ Helm Charts
- ✅ Multi-environment (Dev/Staging/Prod)
- ✅ Security Scanning (Trivy, SonarQube)
- ✅ Monitoring (Prometheus, Grafana)

This is **senior-level architecture** used by modern companies! 🚀

---

*Last Updated: February 2026*
*Project: ShopDeploy E-Commerce Platform*
