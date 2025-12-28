# Jenkins Pipeline Setup Guide for ShopDeploy

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Jenkins Installation](#jenkins-installation)
3. [Required Jenkins Plugins](#required-jenkins-plugins)
4. [Credentials Configuration](#credentials-configuration)
5. [Pipeline Configuration](#pipeline-configuration)
6. [Webhook Setup](#webhook-setup)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before setting up Jenkins, ensure you have:
- An EC2 instance (t3.medium or larger recommended)
- Docker installed
- kubectl configured
- Helm installed
- AWS CLI configured

---

## Jenkins Installation

### Option 1: Install on EC2 (Recommended)

```bash
# Run the installation script
chmod +x scripts/install-jenkins.sh
./scripts/install-jenkins.sh
```

### Option 2: Run Jenkins in Docker

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

### Option 3: Deploy on Kubernetes using Helm

```bash
# Add Jenkins Helm repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --set controller.serviceType=LoadBalancer \
  --set controller.adminPassword=admin123 \
  --wait
```

---

## Required Jenkins Plugins

Install these plugins from **Manage Jenkins → Plugins → Available plugins**:

### Essential Plugins
| Plugin Name | Purpose |
|------------|---------|
| **Pipeline** | Enables Jenkinsfile pipelines |
| **Git** | Git integration |
| **GitHub** | GitHub webhook integration |
| **Docker Pipeline** | Docker build support |
| **Amazon ECR** | AWS ECR authentication |
| **AWS Credentials** | AWS credentials management |
| **Kubernetes** | Kubernetes deployment |
| **Kubernetes CLI** | kubectl integration |

### Recommended Plugins
| Plugin Name | Purpose |
|------------|---------|
| **Blue Ocean** | Modern UI for pipelines |
| **Slack Notification** | Slack integration |
| **HTML Publisher** | Test report publishing |
| **NodeJS** | Node.js build support |
| **AnsiColor** | Colorized console output |
| **Timestamper** | Build timestamps |
| **Build Timeout** | Build timeout control |
| **Workspace Cleanup** | Workspace management |

### Install via CLI
```bash
# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Install plugins via Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin \
  workflow-aggregator git github docker-workflow \
  amazon-ecr aws-credentials kubernetes kubernetes-cli \
  blueocean slack htmlpublisher nodejs ansicolor \
  timestamper build-timeout ws-cleanup
```

---

## Credentials Configuration

### 1. AWS Credentials

Navigate to: **Manage Jenkins → Credentials → System → Global credentials**

#### AWS Credentials Binding
- **Kind**: AWS Credentials
- **ID**: `aws-credentials`
- **Access Key ID**: Your AWS Access Key
- **Secret Access Key**: Your AWS Secret Key

#### AWS Account ID (Secret Text)
- **Kind**: Secret text
- **ID**: `aws-account-id`
- **Secret**: Your 12-digit AWS Account ID

### 2. GitHub Credentials

For private repositories:
- **Kind**: Username with password
- **ID**: `github-credentials`
- **Username**: Your GitHub username
- **Password**: GitHub Personal Access Token (PAT)

### 3. SonarQube Credentials

#### Install SonarQube (Docker)

```bash
# Run SonarQube container on your server
docker run -d --name sonarqube \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:lts-community
```

Access SonarQube at `http://<EC2-IP>:9000` (default login: `admin` / `admin`)

#### Generate SonarQube Token

1. Login to SonarQube → **My Account** → **Security**
2. Generate Token: Name it `jenkins-token`
3. Copy the token

#### Add SonarQube Credential in Jenkins

Navigate to: **Manage Jenkins → Credentials → System → Global credentials**

- **Kind**: Secret text
- **ID**: `sonarqube-token`
- **Secret**: `<paste-your-sonarqube-token>`
- **Description**: SonarQube Authentication Token

#### Configure SonarQube Server

Navigate to: **Manage Jenkins → System → SonarQube servers**

Click **Add SonarQube**:
- **Name**: `SonarQube` *(must match exactly - this name is used in Jenkinsfile)*
- **Server URL**: `http://<SONARQUBE-IP>:9000`
- **Server authentication token**: Select `sonarqube-token`

#### Install SonarQube Scanner Tool

Navigate to: **Manage Jenkins → Tools → SonarQube Scanner installations**

Click **Add SonarQube Scanner**:
- **Name**: `SonarScanner`
- ✅ Install automatically
- **Version**: Latest

### 4. Docker Hub Credentials (Optional)

If pushing images to Docker Hub instead of AWS ECR:

Navigate to: **Manage Jenkins → Credentials → System → Global credentials**

- **Kind**: Username with password
- **ID**: `docker-hub-credentials`
- **Username**: Your Docker Hub username
- **Password**: Docker Hub password or Access Token
- **Description**: Docker Hub Credentials

### 5. Slack Webhook (Optional)

- **Kind**: Secret text
- **ID**: `slack-webhook`
- **Secret**: Slack Incoming Webhook URL

### Credentials Summary

| Credential ID | Kind | Purpose |
|---------------|------|---------|
| `aws-credentials` | AWS Credentials | ECR login, EKS access, AWS CLI |
| `aws-account-id` | Secret text | AWS Account ID for ECR URL |
| `github-credentials` | Username/Password | Git repository access |
| `sonarqube-token` | Secret text | SonarQube authentication |
| `docker-hub-credentials` | Username/Password | Docker Hub (optional) |
| `slack-webhook` | Secret text | Slack notifications (optional) |

### Verify Credentials

```bash
# Test Docker access on Jenkins server
sudo -u jenkins docker ps

# Test AWS ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Test SonarQube connectivity
curl -u admin:admin http://<SONARQUBE-IP>:9000/api/system/status

# Test GitHub access
git ls-remote https://github.com/your-org/shopdeploy.git
```

---

## Pipeline Configuration

### Create New Pipeline Job

1. Click **New Item**
2. Enter name: `shopdeploy-pipeline`
3. Select **Pipeline**
4. Click **OK**

### Configure Pipeline

#### General Settings
- ✅ GitHub project: `https://github.com/your-org/shopdeploy`
- ✅ Discard old builds: Keep last 20

#### Build Triggers
- ✅ GitHub hook trigger for GITScm polling
- ✅ Poll SCM (as backup): `H/5 * * * *`

#### Pipeline Definition
- **Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/your-org/shopdeploy.git`
- **Credentials**: `github-credentials`
- **Branch**: `*/main`
- **Script Path**: `Jenkinsfile`

---

## Webhook Setup

### GitHub Webhook Configuration

1. Go to your GitHub repository
2. Navigate to **Settings → Webhooks → Add webhook**
3. Configure:
   - **Payload URL**: `http://<jenkins-url>:8080/github-webhook/`
   - **Content type**: `application/json`
   - **Secret**: (optional, add for security)
   - **Events**: Select **Just the push event** or **Let me select individual events**

### Verify Webhook
- Send a test commit
- Check **Recent Deliveries** in GitHub webhook settings
- Verify Jenkins triggers the build

---

## Pipeline Parameters

The Jenkinsfile supports these parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ENVIRONMENT` | Choice | dev | Target environment (dev/staging/prod) |
| `SKIP_TESTS` | Boolean | false | Skip test stage |
| `FORCE_DEPLOY` | Boolean | false | Force deployment |
| `BACKEND_VERSION` | String | "" | Specific backend version |
| `FRONTEND_VERSION` | String | "" | Specific frontend version |

---

## Environment Variables

Set these in Jenkins (Manage Jenkins → System → Global properties):

```properties
AWS_REGION=us-east-1
EKS_CLUSTER_NAME=shopdeploy-prod-eks
K8S_NAMESPACE=shopdeploy
SLACK_CHANNEL=#devops-alerts
```

---

## Pipeline Stages Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ShopDeploy CI/CD Pipeline                        │
├─────────────────────────────────────────────────────────────────────┤
│  1. Checkout          → Clone source code from Git                  │
│  2. Detect Changes    → Identify modified components                │
│  3. Install Deps      → npm ci for backend/frontend (parallel)      │
│  4. Code Quality      → Lint + Security scan (parallel)             │
│  5. Tests             → Unit tests + coverage (parallel)            │
│  6. Build Images      → Docker build for changed components         │
│  7. Push to ECR       → Push images to AWS ECR                      │
│  8. Deploy to EKS     → Helm deploy to Kubernetes                   │
│  9. Approval Gate     → Manual approval for production              │
│ 10. Production Deploy → Canary deployment to prod                   │
│ 11. Smoke Tests       → Post-deployment validation                  │
│ 12. Cleanup           → Docker image pruning                        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Security Best Practices

### 1. Secure Jenkins Instance
```bash
# Configure Jenkins behind a reverse proxy (nginx)
sudo apt install nginx -y

# /etc/nginx/sites-available/jenkins
server {
    listen 80;
    server_name jenkins.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2. Enable HTTPS with SSL
```bash
sudo certbot --nginx -d jenkins.yourdomain.com
```

### 3. Configure Security Realm
- Use **LDAP** or **Active Directory** for authentication
- Enable **Matrix-based security** for fine-grained access control

---

## Troubleshooting

### Common Issues

#### 1. Docker Permission Denied
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

#### 2. AWS Credentials Not Working
```bash
# Test AWS CLI in Jenkins shell
aws sts get-caller-identity
aws ecr get-login-password --region us-east-1
```

#### 3. kubectl Context Issues
```bash
# Update kubeconfig in Jenkins
aws eks update-kubeconfig --region us-east-1 --name shopdeploy-prod-eks
```

#### 4. Build Failing on npm ci
```bash
# Clear npm cache
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
```

---

## Backup Jenkins Configuration

```bash
# Backup Jenkins home
tar -czvf jenkins-backup-$(date +%Y%m%d).tar.gz /var/lib/jenkins

# Backup specific configurations
tar -czvf jenkins-config-backup.tar.gz \
  /var/lib/jenkins/config.xml \
  /var/lib/jenkins/credentials.xml \
  /var/lib/jenkins/jobs/*/config.xml
```

---

## Next Steps

1. [Set up Prometheus & Grafana Monitoring](./MONITORING-SETUP-GUIDE.md)
2. [Configure Helm Charts](./HELM-SETUP-GUIDE.md)
3. [Review EC2 Deployment Guide](../EC2-DEPLOYMENT-GUIDE.md)
