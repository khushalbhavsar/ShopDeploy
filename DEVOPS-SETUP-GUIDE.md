# ShopDeploy DevOps Setup Guide

## Complete CI/CD and Monitoring Setup

This guide covers the complete setup of Jenkins, Prometheus, Grafana, and Helm for the ShopDeploy e-commerce application.

---

## Quick Start

### Prerequisites Checklist

- [ ] AWS CLI configured (`aws configure`)
- [ ] kubectl installed and configured
- [ ] Docker installed and running
- [ ] Helm 3.x installed
- [ ] EKS cluster running

### One-Line Setup Commands

```bash
# Windows PowerShell
.\scripts\install-jenkins.ps1 -InstallMethod docker
.\scripts\install-monitoring.ps1 -Namespace monitoring
.\scripts\helm-deploy.ps1 -Component all -Environment dev

# Linux/Mac
./scripts/install-jenkins.sh
./scripts/install-monitoring.sh monitoring
./scripts/helm-deploy.sh all latest dev
```

---

## Setup Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ShopDeploy DevOps Setup Flow                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Step 1: Infrastructure                Step 2: CI/CD                        │
│  ┌─────────────────────────┐           ┌─────────────────────────┐         │
│  │  • Terraform (EKS/VPC)  │           │  • Jenkins Installation │         │
│  │  • ECR Repositories     │   ──▶     │  • Plugin Configuration │         │
│  │  • IAM Roles            │           │  • Credentials Setup    │         │
│  └─────────────────────────┘           └─────────────────────────┘         │
│                                                   │                         │
│                                                   ▼                         │
│  Step 4: Application                   Step 3: Monitoring                   │
│  ┌─────────────────────────┐           ┌─────────────────────────┐         │
│  │  • Helm Deploy Backend  │   ◀──     │  • Prometheus Install   │         │
│  │  • Helm Deploy Frontend │           │  • Grafana Setup        │         │
│  │  • Configure Ingress    │           │  • Alert Rules          │         │
│  └─────────────────────────┘           └─────────────────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Jenkins Setup

### Installation Options

| Method | Best For | Command |
|--------|----------|---------|
| Docker | Local development | `.\scripts\install-jenkins.ps1 -InstallMethod docker` |
| Chocolatey | Windows server | `.\scripts\install-jenkins.ps1 -InstallMethod chocolatey` |
| Shell Script | Linux/EC2 | `./scripts/install-jenkins.sh` |

### Required Jenkins Plugins

Install these plugins after Jenkins starts:

```
Pipeline, Git, GitHub, Docker Pipeline, Amazon ECR, 
AWS Credentials, Kubernetes, Kubernetes CLI, Blue Ocean,
Slack Notification, HTML Publisher, NodeJS, AnsiColor
```

### Configure Credentials

Navigate to: **Manage Jenkins → Credentials → System → Global**

| ID | Type | Description |
|----|------|-------------|
| `aws-credentials` | AWS Credentials | Access Key + Secret Key |
| `aws-account-id` | Secret Text | 12-digit AWS Account ID |
| `github-credentials` | Username/Password | GitHub PAT |
| `slack-webhook` | Secret Text | Slack Webhook URL |

### Create Pipeline Job

1. New Item → Enter name `shopdeploy-pipeline`
2. Select **Pipeline** → OK
3. Pipeline Definition: **Pipeline script from SCM**
4. SCM: Git → Repository URL
5. Script Path: `Jenkinsfile`

📖 **Full Guide**: [docs/JENKINS-SETUP-GUIDE.md](docs/JENKINS-SETUP-GUIDE.md)

---

## Step 2: Helm Charts Setup

### Helm Installation

```bash
# Windows
choco install kubernetes-helm

# Linux/Mac
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Add Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Deploy Application

```bash
# Deploy to development
.\scripts\helm-deploy.ps1 -Component all -ImageTag latest -Environment dev

# Deploy to staging
.\scripts\helm-deploy.ps1 -Component all -ImageTag v1.0.0 -Environment staging

# Deploy to production
.\scripts\helm-deploy.ps1 -Component all -ImageTag v1.0.0 -Environment prod
```

### Chart Structure

```
helm/
├── backend/
│   ├── Chart.yaml
│   ├── values.yaml           # Default values
│   ├── values-dev.yaml       # Development overrides
│   ├── values-staging.yaml   # Staging overrides
│   └── values-prod.yaml      # Production overrides
│
└── frontend/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-dev.yaml
    ├── values-staging.yaml
    └── values-prod.yaml
```

📖 **Full Guide**: [docs/HELM-SETUP-GUIDE.md](docs/HELM-SETUP-GUIDE.md)

---

## Step 3: Monitoring Setup (Prometheus & Grafana)

### Quick Installation

```powershell
# Windows PowerShell
.\scripts\install-monitoring.ps1 -Namespace monitoring -GrafanaPassword "YourSecurePassword"
```

```bash
# Linux/Mac
export GRAFANA_ADMIN_PASSWORD="YourSecurePassword"
./monitoring/install-monitoring.sh monitoring
```

### Access Monitoring

```bash
# Port forward Grafana
kubectl port-forward svc/grafana 3000:80 -n monitoring
# Open: http://localhost:3000

# Port forward Prometheus
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
# Open: http://localhost:9090
```

### Default Dashboards

| Dashboard | ID | Description |
|-----------|-----|-------------|
| Kubernetes Cluster | 7249 | Cluster overview |
| Node Exporter | 1860 | Host metrics |
| Kubernetes Pods | 6417 | Pod metrics |
| ShopDeploy Custom | - | Application metrics |

### Alert Rules Configured

- ✅ High CPU Usage (>80% for 5min)
- ✅ High Memory Usage (>85% for 5min)
- ✅ Pod Not Ready (5min)
- ✅ High Pod Restart Count (>5/hour)
- ✅ High Response Time (95th percentile >2s)
- ✅ High Error Rate (>5%)
- ✅ Low Disk Space (<15%)
- ✅ HPA at Max Capacity

📖 **Full Guide**: [docs/MONITORING-SETUP-GUIDE.md](docs/MONITORING-SETUP-GUIDE.md)

---

## Step 4: Complete Pipeline Flow

### Jenkins Pipeline Stages

```
1. Checkout         → Clone repository
2. Detect Changes   → Identify modified components
3. Install Deps     → npm ci (parallel)
4. Code Quality     → Lint + Security scan (parallel)
5. Tests            → Unit tests + coverage (parallel)
6. Build Images     → Docker build
7. Push to ECR      → Push to AWS ECR
8. Deploy to EKS    → Helm deployment
9. Approval Gate    → Manual approval (prod only)
10. Production      → Canary deployment
11. Smoke Tests     → Health checks
12. Cleanup         → Docker prune
```

### Environment Promotion

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     DEV     │ ──▶ │   STAGING   │ ──▶ │    PROD     │
│             │     │             │     │             │
│  Auto-merge │     │  Auto-merge │     │   Manual    │
│  to staging │     │  to prod    │     │  Approval   │
└─────────────┘     └─────────────┘     └─────────────┘
     1 pod              2 pods           3-20 pods
   No HPA              HPA 2-5          HPA 3-20
```

---

## Useful Commands

### Kubernetes

```bash
# View all resources in namespace
kubectl get all -n shopdeploy

# View logs
kubectl logs -f deployment/shopdeploy-backend -n shopdeploy

# Describe pod
kubectl describe pod <pod-name> -n shopdeploy

# Execute into pod
kubectl exec -it <pod-name> -n shopdeploy -- /bin/sh
```

### Helm

```bash
# List releases
helm list -n shopdeploy

# View release status
helm status shopdeploy-backend -n shopdeploy

# Rollback
helm rollback shopdeploy-backend -n shopdeploy

# Uninstall
helm uninstall shopdeploy-backend -n shopdeploy
```

### Monitoring

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
# Navigate to: http://localhost:9090/targets

# Check Alertmanager
kubectl port-forward svc/prometheus-alertmanager 9093:80 -n monitoring
# Navigate to: http://localhost:9093
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Image pull error | Check ECR login: `aws ecr get-login-password` |
| Pod CrashLoopBackOff | Check logs: `kubectl logs <pod>` |
| Helm release stuck | Force delete: `helm uninstall --no-hooks` |
| Jenkins build fails | Check credentials configuration |
| Prometheus no data | Verify pod annotations for scraping |

### Debug Commands

```bash
# Check events
kubectl get events -n shopdeploy --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n shopdeploy

# Validate Helm template
helm template ./helm/backend --debug
```

---

## Related Documentation

- [Jenkins Setup Guide](docs/JENKINS-SETUP-GUIDE.md)
- [Monitoring Setup Guide](docs/MONITORING-SETUP-GUIDE.md)
- [Helm Charts Guide](docs/HELM-SETUP-GUIDE.md)
- [EC2 Deployment Guide](EC2-DEPLOYMENT-GUIDE.md)
- [Kubernetes Manifests](k8s/README.md)

---

## Support

For issues or questions, create an issue in the repository or contact the DevOps team.
