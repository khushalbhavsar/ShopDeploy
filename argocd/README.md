# 🚀 ArgoCD Configuration for ShopDeploy

## Overview

This directory contains ArgoCD manifests for GitOps-based continuous deployment of the ShopDeploy e-commerce application.

---

## 📁 Directory Structure

```
argocd/
├── README.md                          # This file
├── applications/
│   ├── dev/
│   │   ├── backend.yaml              # Backend app for dev
│   │   └── frontend.yaml             # Frontend app for dev
│   ├── staging/
│   │   ├── backend.yaml              # Backend app for staging
│   │   └── frontend.yaml             # Frontend app for staging
│   └── prod/
│       ├── backend.yaml              # Backend app for prod
│       └── frontend.yaml             # Frontend app for prod
├── applicationsets/
│   └── all-environments.yaml         # ApplicationSet (alternative approach)
├── notifications/
│   ├── notifications-cm.yaml         # Slack notification config
│   └── notifications-secret.yaml     # Slack token secret
└── projects/
    └── shopdeploy-project.yaml       # AppProject definition
```

---

## 🔧 Prerequisites

### 1. Install ArgoCD on EKS

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

### 2. Expose ArgoCD UI

```bash
# Option 1: LoadBalancer (AWS)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Option 2: Port Forward (local testing)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 3. Get Initial Admin Password

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login via CLI
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>
```

---

## 🚀 Deployment Options

### Option 1: Individual Applications (Recommended for Control)

```bash
# Deploy project first
kubectl apply -f argocd/projects/shopdeploy-project.yaml

# Deploy dev environment
kubectl apply -f argocd/applications/dev/

# Deploy staging environment
kubectl apply -f argocd/applications/staging/

# Deploy production environment
kubectl apply -f argocd/applications/prod/
```

### Option 2: ApplicationSet (All Environments at Once)

```bash
# Deploy project first
kubectl apply -f argocd/projects/shopdeploy-project.yaml

# Deploy all environments using ApplicationSet
kubectl apply -f argocd/applicationsets/all-environments.yaml
```

---

## 📬 Configure Notifications (Optional)

```bash
# Create secret with Slack token
kubectl apply -f argocd/notifications/notifications-secret.yaml

# Apply notification configuration
kubectl apply -f argocd/notifications/notifications-cm.yaml
```

---

## 🔄 GitOps Workflow

```
┌──────────────────────────────────────────────────────────────────────┐
│                        GitOps Deployment Flow                         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   Developer         Jenkins CI           Git Repo          ArgoCD    │
│       │                  │                   │                │      │
│       │  Push Code       │                   │                │      │
│       │─────────────────>│                   │                │      │
│       │                  │                   │                │      │
│       │                  │  Build & Push     │                │      │
│       │                  │  Docker Image     │                │      │
│       │                  │─────────────────> │                │      │
│       │                  │                   │                │      │
│       │                  │  Update image.tag │                │      │
│       │                  │  in gitops/       │                │      │
│       │                  │─────────────────> │                │      │
│       │                  │                   │                │      │
│       │                  │                   │  Detect Change │      │
│       │                  │                   │ <──────────────│      │
│       │                  │                   │                │      │
│       │                  │                   │  Auto Sync     │      │
│       │                  │                   │ ──────────────>│      │
│       │                  │                   │                │      │
│       │                  │                   │           ┌────┴────┐ │
│       │                  │                   │           │   EKS   │ │
│       │                  │                   │           │ Cluster │ │
│       │                  │                   │           └─────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ CI Pipeline GitOps Stage

Add this stage to your Jenkins CI pipeline to update GitOps values:

```groovy
stage('Update GitOps') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: 'github-credentials',
            usernameVariable: 'GIT_USER',
            passwordVariable: 'GIT_TOKEN'
        )]) {
            sh '''
                # Clone repo
                git clone https://${GIT_USER}:${GIT_TOKEN}@github.com/YOUR_USERNAME/shopdeploy.git gitops-temp
                cd gitops-temp

                # Update image tags
                sed -i "s|tag:.*|tag: \\"${IMAGE_TAG}\\"|g" gitops/${TARGET_ENV}/backend-values.yaml
                sed -i "s|tag:.*|tag: \\"${IMAGE_TAG}\\"|g" gitops/${TARGET_ENV}/frontend-values.yaml

                # Commit and push
                git config user.email "jenkins@shopdeploy.com"
                git config user.name "Jenkins CI"
                git add .
                git commit -m "Deploy ${IMAGE_TAG} to ${TARGET_ENV}"
                git push

                # Cleanup
                cd ..
                rm -rf gitops-temp
            '''
        }
    }
}
```

---

## 🔍 Verify Deployment

### Check ArgoCD Applications

```bash
# List all applications
argocd app list

# Get application details
argocd app get shopdeploy-backend-dev
argocd app get shopdeploy-frontend-dev

# Sync manually if needed
argocd app sync shopdeploy-backend-dev
```

### Check via kubectl

```bash
# Check pods
kubectl get pods -n shopdeploy-dev
kubectl get pods -n shopdeploy-staging
kubectl get pods -n shopdeploy-prod

# Check services
kubectl get svc -n shopdeploy-dev
```

---

## 🛡️ Best Practices

1. **Never edit YAML directly on EC2** - Always commit through Git
2. **Use feature branches** for changes, merge to main after review
3. **Enable auto-sync with selfHeal** for automatic drift correction
4. **Use Sealed Secrets** for sensitive data in production
5. **Set up sync windows** for production to control deployment times
6. **Configure notifications** for deployment visibility

---

## 🔗 Useful Links

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ApplicationSet Controller](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)

---

*Last Updated: February 2026*
