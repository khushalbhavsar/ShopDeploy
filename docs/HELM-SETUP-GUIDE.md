# Helm Charts Setup Guide for ShopDeploy

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Helm Installation](#helm-installation)
4. [Chart Structure](#chart-structure)
5. [Backend Deployment](#backend-deployment)
6. [Frontend Deployment](#frontend-deployment)
7. [Configuration](#configuration)
8. [Common Operations](#common-operations)
9. [CI/CD Integration](#cicd-integration)

---

## Overview

ShopDeploy uses Helm charts for Kubernetes deployments:

```
helm/
├── backend/          # Backend API Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── hpa.yaml
│       ├── pdb.yaml
│       └── serviceaccount.yaml
│
└── frontend/         # Frontend Helm chart
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        ├── hpa.yaml
        ├── pdb.yaml
        └── serviceaccount.yaml
```

---

## Prerequisites

- Kubernetes cluster (EKS recommended)
- kubectl configured
- AWS CLI configured
- Docker images pushed to ECR

---

## Helm Installation

### Install Helm

```bash
# Using script
chmod +x scripts/install-helm.sh
./scripts/install-helm.sh

# Or using curl (Linux/Mac)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Using Chocolatey (Windows)
choco install kubernetes-helm
```

### Verify Installation

```bash
helm version
# version.BuildInfo{Version:"v3.13.3", ...}
```

### Add Required Repositories

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

## Chart Structure

### Backend Chart Components

| File | Purpose |
|------|---------|
| `Chart.yaml` | Chart metadata and version |
| `values.yaml` | Default configuration values |
| `templates/deployment.yaml` | Kubernetes Deployment |
| `templates/service.yaml` | Kubernetes Service |
| `templates/ingress.yaml` | Ingress for routing |
| `templates/hpa.yaml` | Horizontal Pod Autoscaler |
| `templates/pdb.yaml` | Pod Disruption Budget |
| `templates/serviceaccount.yaml` | Service Account |

### Key Values Configuration

```yaml
# helm/backend/values.yaml
replicaCount: 2

image:
  repository: ""  # ECR repository URL
  tag: "latest"
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

---

## Backend Deployment

### Deploy Backend

```bash
# Set variables
export AWS_ACCOUNT_ID="123456789012"
export AWS_REGION="us-east-1"
export IMAGE_TAG="1.0.0"

# Deploy backend
helm upgrade --install shopdeploy-backend ./helm/backend \
    --namespace shopdeploy \
    --create-namespace \
    --set image.repository="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/shopdeploy-prod-backend" \
    --set image.tag="${IMAGE_TAG}" \
    --set env.NODE_ENV="production" \
    --set env.MONGODB_URI="mongodb://mongodb:27017/shopdeploy" \
    --wait --timeout 5m
```

### Environment-Specific Deployments

```bash
# Development
helm upgrade --install shopdeploy-backend-dev ./helm/backend \
    --namespace shopdeploy-dev \
    --create-namespace \
    -f helm/backend/values.yaml \
    -f helm/backend/values-dev.yaml

# Staging
helm upgrade --install shopdeploy-backend-staging ./helm/backend \
    --namespace shopdeploy-staging \
    --create-namespace \
    -f helm/backend/values.yaml \
    -f helm/backend/values-staging.yaml

# Production
helm upgrade --install shopdeploy-backend-prod ./helm/backend \
    --namespace shopdeploy \
    --create-namespace \
    -f helm/backend/values.yaml \
    -f helm/backend/values-prod.yaml
```

---

## Frontend Deployment

### Deploy Frontend

```bash
# Deploy frontend
helm upgrade --install shopdeploy-frontend ./helm/frontend \
    --namespace shopdeploy \
    --set image.repository="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/shopdeploy-prod-frontend" \
    --set image.tag="${IMAGE_TAG}" \
    --set env.VITE_API_URL="https://api.shopdeploy.example.com" \
    --wait --timeout 5m
```

---

## Configuration

### Create Environment-Specific Values Files

#### Development Values (`values-dev.yaml`)

```yaml
# helm/backend/values-dev.yaml
replicaCount: 1

image:
  pullPolicy: Always

resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

autoscaling:
  enabled: false

env:
  NODE_ENV: development
  LOG_LEVEL: debug
```

#### Staging Values (`values-staging.yaml`)

```yaml
# helm/backend/values-staging.yaml
replicaCount: 2

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 300m
    memory: 384Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 75

env:
  NODE_ENV: staging
  LOG_LEVEL: info
```

#### Production Values (`values-prod.yaml`)

```yaml
# helm/backend/values-prod.yaml
replicaCount: 3

resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1024Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70

env:
  NODE_ENV: production
  LOG_LEVEL: warn

# Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 2

# Affinity for spreading across nodes
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - backend
          topologyKey: kubernetes.io/hostname
```

### Using Secrets

```bash
# Create secret for sensitive values
kubectl create secret generic backend-secrets \
    --namespace shopdeploy \
    --from-literal=mongodb-uri="mongodb://user:pass@host:27017/db" \
    --from-literal=jwt-secret="your-jwt-secret" \
    --from-literal=cloudinary-api-key="your-api-key"

# Reference in values.yaml
existingSecret: backend-secrets
```

---

## Common Operations

### List Releases

```bash
helm list -n shopdeploy
```

### Check Release Status

```bash
helm status shopdeploy-backend -n shopdeploy
```

### View Release History

```bash
helm history shopdeploy-backend -n shopdeploy
```

### Upgrade Release

```bash
helm upgrade shopdeploy-backend ./helm/backend \
    --namespace shopdeploy \
    --set image.tag="2.0.0" \
    --wait
```

### Rollback Release

```bash
# Rollback to previous revision
helm rollback shopdeploy-backend -n shopdeploy

# Rollback to specific revision
helm rollback shopdeploy-backend 3 -n shopdeploy
```

### Uninstall Release

```bash
helm uninstall shopdeploy-backend -n shopdeploy
```

### Debug Template Rendering

```bash
# Dry run - see what would be deployed
helm upgrade --install shopdeploy-backend ./helm/backend \
    --namespace shopdeploy \
    --dry-run --debug

# Template only - render templates locally
helm template shopdeploy-backend ./helm/backend \
    --namespace shopdeploy \
    --set image.tag="1.0.0"
```

---

## CI/CD Integration

### Jenkins Pipeline Helm Commands

From the Jenkinsfile, Helm is used in the deploy stage:

```groovy
stage('Deploy to EKS') {
    steps {
        script {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
                              credentialsId: 'aws-credentials']]) {
                sh """
                    # Configure kubectl
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                    
                    # Deploy Backend
                    helm upgrade --install ${HELM_RELEASE_BACKEND} ./helm/backend \
                        --namespace ${K8S_NAMESPACE} \
                        --create-namespace \
                        --set image.repository=${ECR_REGISTRY}/${ECR_BACKEND_REPO} \
                        --set image.tag=${IMAGE_TAG} \
                        --wait --timeout 10m
                    
                    # Deploy Frontend
                    helm upgrade --install ${HELM_RELEASE_FRONTEND} ./helm/frontend \
                        --namespace ${K8S_NAMESPACE} \
                        --set image.repository=${ECR_REGISTRY}/${ECR_FRONTEND_REPO} \
                        --set image.tag=${IMAGE_TAG} \
                        --wait --timeout 10m
                """
            }
        }
    }
}
```

### Deploy Script

Create a reusable deploy script:

```bash
#!/bin/bash
# scripts/helm-deploy.sh

set -e

COMPONENT=${1:-backend}
IMAGE_TAG=${2:-latest}
ENVIRONMENT=${3:-dev}
NAMESPACE="shopdeploy-${ENVIRONMENT}"

if [ "$ENVIRONMENT" == "prod" ]; then
    NAMESPACE="shopdeploy"
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Deploying ${COMPONENT} version ${IMAGE_TAG} to ${ENVIRONMENT}..."

helm upgrade --install "shopdeploy-${COMPONENT}" "./helm/${COMPONENT}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set image.repository="${ECR_REGISTRY}/shopdeploy-prod-${COMPONENT}" \
    --set image.tag="${IMAGE_TAG}" \
    --values "./helm/${COMPONENT}/values.yaml" \
    --values "./helm/${COMPONENT}/values-${ENVIRONMENT}.yaml" \
    --wait --timeout 10m

echo "Deployment complete!"
kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${COMPONENT}"
```

---

## Helm Best Practices

### 1. Version Control
- Always version your charts (`Chart.yaml`)
- Tag releases in Git
- Use semantic versioning

### 2. Values Management
- Use environment-specific values files
- Never commit secrets to Git
- Use Kubernetes secrets or external secret managers

### 3. Resource Management
```yaml
resources:
  requests:
    cpu: 100m      # What the pod needs
    memory: 256Mi
  limits:
    cpu: 500m      # Max allowed
    memory: 512Mi
```

### 4. Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: 5000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /api/health
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 5. Pod Disruption Budgets
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1  # or maxUnavailable: 1
```

---

## Troubleshooting

### Common Issues

#### 1. Image Pull Errors
```bash
# Check imagePullSecrets
kubectl get secret -n shopdeploy

# Verify ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}
```

#### 2. Helm Release Stuck
```bash
# Check release status
helm status shopdeploy-backend -n shopdeploy

# Force uninstall if stuck
helm uninstall shopdeploy-backend -n shopdeploy --no-hooks
```

#### 3. Template Errors
```bash
# Validate templates
helm lint ./helm/backend

# Debug template rendering
helm template ./helm/backend --debug
```

#### 4. Resource Conflicts
```bash
# Check for existing resources
kubectl get all -n shopdeploy

# Delete and reinstall
helm uninstall shopdeploy-backend -n shopdeploy
helm install shopdeploy-backend ./helm/backend -n shopdeploy
```

---

## Next Steps

1. [Set up Jenkins Pipeline](./JENKINS-SETUP-GUIDE.md)
2. [Configure Monitoring](./MONITORING-SETUP-GUIDE.md)
3. [Review Kubernetes Manifests](../k8s/README.md)
