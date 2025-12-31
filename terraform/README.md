# 🏗️ ShopDeploy - Terraform Infrastructure

<p align="center">
  <img src="https://img.shields.io/badge/Terraform-1.5+-7B42BC?style=for-the-badge&logo=terraform" alt="Terraform"/>
  <img src="https://img.shields.io/badge/AWS-Cloud-FF9900?style=for-the-badge&logo=amazon-aws" alt="AWS"/>
  <img src="https://img.shields.io/badge/EKS-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes" alt="EKS"/>
  <img src="https://img.shields.io/badge/IaC-Infrastructure%20as%20Code-00D4AA?style=for-the-badge" alt="IaC"/>
</p>

This directory contains Terraform configurations for provisioning the complete AWS infrastructure required to run the ShopDeploy e-commerce application.

---

## 📋 Table of Contents

- [What is Terraform?](#-what-is-terraform)
- [Why Terraform for ShopDeploy?](#-why-terraform-for-shopdeploy)
- [Infrastructure as Code (IaC) Deep Dive](#-infrastructure-as-code-iac-deep-dive)
- [Terraform vs Other Tools](#-terraform-vs-other-tools)
- [How Terraform Works](#-how-terraform-works)
- [What This Creates](#-what-this-creates)
- [Architecture Diagram](#-architecture-diagram)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Module Structure](#-module-structure)
- [Configuration](#-configuration)
- [Deployment Guide](#-deployment-guide)
- [Outputs](#-outputs)
- [Cost Estimation](#-cost-estimation)
- [Best Practices](#-best-practices)
- [Troubleshooting](#-troubleshooting)

---

## 🌍 What is Terraform?

**Terraform** is an open-source Infrastructure as Code (IaC) tool created by HashiCorp that allows you to define, provision, and manage cloud infrastructure using declarative configuration files.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Provider** | Plugin that allows Terraform to interact with cloud platforms (AWS, Azure, GCP) |
| **Resource** | A single piece of infrastructure (EC2 instance, VPC, S3 bucket) |
| **Module** | Reusable, self-contained package of Terraform configurations |
| **State** | JSON file that tracks the current state of your infrastructure |
| **Plan** | Preview of changes Terraform will make before applying |
| **Apply** | Execute the planned changes to create/modify infrastructure |

### Terraform Workflow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Write     │────▶│    Init     │────▶│    Plan     │────▶│   Apply     │
│   .tf files │     │  Download   │     │   Preview   │     │   Execute   │
│             │     │  providers  │     │   changes   │     │   changes   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

---

## 🎯 Why Terraform for ShopDeploy?

### The Problem Without Terraform

**Manual Infrastructure Setup (The Old Way):**

```
❌ Login to AWS Console
❌ Click through 50+ screens to create VPC
❌ Manually configure subnets, route tables
❌ Create EKS cluster via console (30+ clicks)
❌ Set up IAM roles and policies manually
❌ Create ECR repositories one by one
❌ Hope you didn't miss any configuration
❌ Document everything manually
❌ Repeat for staging, production environments
❌ No way to track what changed and when
```

**Time Required:** 4-8 hours per environment  
**Error Rate:** High (human mistakes)  
**Reproducibility:** Nearly impossible

### The Solution With Terraform

**Infrastructure as Code (The Modern Way):**

```
✅ Write infrastructure in .tf files once
✅ Run `terraform apply`
✅ Entire infrastructure created in 15-20 minutes
✅ Same code works for dev, staging, prod
✅ Changes tracked in Git history
✅ Team can review infrastructure changes
✅ Disaster recovery: rebuild everything instantly
✅ Destroy non-prod to save costs: `terraform destroy`
```

**Time Required:** 15-20 minutes (automated)  
**Error Rate:** Near zero (consistent execution)  
**Reproducibility:** 100% identical every time

---

## 📚 Infrastructure as Code (IaC) Deep Dive

### What is Infrastructure as Code?

Infrastructure as Code (IaC) is the practice of managing and provisioning computing infrastructure through machine-readable configuration files rather than manual processes.

### Core Benefits for ShopDeploy

| Benefit | Without IaC | With Terraform |
|---------|-------------|----------------|
| **Speed** | 4-8 hours manual setup | 15-20 minutes automated |
| **Consistency** | Different each time | Identical every deployment |
| **Documentation** | Separate docs (outdated) | Code IS documentation |
| **Version Control** | None | Full Git history |
| **Collaboration** | One person at a time | Team reviews via PRs |
| **Rollback** | Manual, error-prone | `git revert` + `terraform apply` |
| **Audit Trail** | None | Complete change history |
| **Cost Control** | Always running | `terraform destroy` when idle |
| **Testing** | Test in production 😱 | Test in dev first |
| **Disaster Recovery** | Rebuild manually (days) | Rebuild automatically (minutes) |

### Real-World Example

**Scenario:** Your production EKS cluster crashes at 2 AM

**Without Terraform:**
```
😰 Panic mode activated
📞 Call the one person who set it up
🤔 Try to remember all the settings
⏰ 4-8 hours to recreate manually
💸 Massive downtime costs
```

**With Terraform:**
```bash
# Just run:
terraform apply -auto-approve

# ☕ Wait 15 minutes
# ✅ Complete infrastructure restored
```

---

## ⚔️ Terraform vs Other Tools

### Comparison Matrix

| Feature | Terraform | CloudFormation | Pulumi | Ansible |
|---------|-----------|----------------|--------|---------|
| **Cloud Support** | Multi-cloud | AWS only | Multi-cloud | Multi-cloud |
| **Language** | HCL (simple) | JSON/YAML | Python/JS/Go | YAML |
| **State Management** | Built-in | AWS managed | Built-in | None |
| **Learning Curve** | Medium | Medium | High | Low |
| **Community** | Huge | AWS only | Growing | Huge |
| **Drift Detection** | Yes | Yes | Yes | No |
| **Preview Changes** | `terraform plan` | Change sets | `pulumi preview` | Check mode |
| **Modularity** | Excellent | StackSets | Good | Roles |
| **Cost** | Free | Free | Paid features | Free |

### Why We Chose Terraform

1. **Multi-Cloud Ready**: If we ever migrate to Azure/GCP, same concepts apply
2. **HCL is Readable**: Easier than JSON/YAML for infrastructure
3. **Massive Ecosystem**: Pre-built modules for almost everything
4. **State Management**: Tracks exactly what exists vs what's defined
5. **Plan Before Apply**: See exactly what will change before executing
6. **Industry Standard**: Most DevOps engineers know Terraform
7. **Active Development**: HashiCorp constantly improves it

---

## ⚙️ How Terraform Works

### The Terraform Lifecycle

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        TERRAFORM LIFECYCLE                                │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   1. WRITE                    2. INIT                                    │
│   ┌─────────────────┐        ┌─────────────────┐                        │
│   │  main.tf        │        │ Download AWS    │                        │
│   │  variables.tf   │───────▶│ provider plugin │                        │
│   │  outputs.tf     │        │ Initialize      │                        │
│   └─────────────────┘        └────────┬────────┘                        │
│                                       │                                  │
│   3. PLAN                             ▼                                  │
│   ┌─────────────────────────────────────────────────────┐               │
│   │  Compare desired state (.tf) vs current state       │               │
│   │  ┌─────────────┐         ┌─────────────┐           │               │
│   │  │ .tf files   │   vs    │ terraform   │           │               │
│   │  │ (desired)   │         │ .tfstate    │           │               │
│   │  └─────────────┘         │ (current)   │           │               │
│   │                          └─────────────┘           │               │
│   │  Output: Execution plan (what will change)         │               │
│   └─────────────────────────────────────────────────────┘               │
│                                       │                                  │
│   4. APPLY                            ▼                                  │
│   ┌─────────────────────────────────────────────────────┐               │
│   │  Execute changes via AWS API                        │               │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────┐         │               │
│   │  │ Create   │  │ Update   │  │ Delete   │         │               │
│   │  │ resources│  │ resources│  │ resources│         │               │
│   │  └──────────┘  └──────────┘  └──────────┘         │               │
│   │  Update terraform.tfstate                          │               │
│   └─────────────────────────────────────────────────────┘               │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### State File Explained

The `terraform.tfstate` file is **critical** - it maps your configuration to real AWS resources:

```json
{
  "resources": [
    {
      "type": "aws_vpc",
      "name": "main",
      "instances": [
        {
          "attributes": {
            "id": "vpc-0abc123def456",
            "cidr_block": "10.0.0.0/16"
          }
        }
      ]
    }
  ]
}
```

**Why State Matters:**
- Terraform knows VPC `vpc-0abc123def456` belongs to your `aws_vpc.main` resource
- Without state, Terraform would create duplicates every time
- Remote state (S3) enables team collaboration

### Providers in This Project

```hcl
# Providers used in ShopDeploy
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"    # AWS resources
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"  # K8s resources
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"   # Helm chart deployments
      version = "~> 2.11"
    }
  }
}
```

---

## 🤔 Why Terraform?

### Infrastructure as Code (IaC) Benefits

| Benefit | Description |
|---------|-------------|
| **Version Control** | Track infrastructure changes in Git like application code |
| **Reproducibility** | Create identical environments (dev, staging, prod) consistently |
| **Automation** | Eliminate manual AWS console clicking and human errors |
| **Documentation** | Code itself documents the infrastructure setup |
| **Collaboration** | Team members can review and contribute to infrastructure |
| **Disaster Recovery** | Quickly rebuild entire infrastructure if needed |
| **Cost Management** | Easily destroy non-production environments when not in use |

### Why Terraform Over Other Tools?

- **Cloud Agnostic**: Works with AWS, Azure, GCP, and 100+ providers
- **Declarative Syntax**: Define what you want, Terraform figures out how
- **State Management**: Tracks real-world infrastructure state
- **Plan Before Apply**: Preview changes before making them
- **Large Community**: Extensive modules and documentation available
- **HashiCorp Ecosystem**: Integrates with Vault, Consul, etc.

---

## 🏗️ What This Creates

### Complete AWS Infrastructure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-east-1)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        VPC (10.0.0.0/16)                            │   │
│  │                                                                     │   │
│  │   ┌─────────────────────────────────────────────────────────────┐  │   │
│  │   │              Public Subnets (3 AZs)                         │  │   │
│  │   │   ┌─────────┐  ┌─────────┐  ┌─────────┐                    │  │   │
│  │   │   │10.0.1.0 │  │10.0.2.0 │  │10.0.3.0 │                    │  │   │
│  │   │   │  /24    │  │  /24    │  │  /24    │                    │  │   │
│  │   │   └────┬────┘  └────┬────┘  └────┬────┘                    │  │   │
│  │   │        │            │            │                          │  │   │
│  │   │        └────────────┼────────────┘                          │  │   │
│  │   │                     │                                       │  │   │
│  │   │              ┌──────┴──────┐                                │  │   │
│  │   │              │ NAT Gateway │                                │  │   │
│  │   │              └──────┬──────┘                                │  │   │
│  │   └─────────────────────┼───────────────────────────────────────┘  │   │
│  │                         │                                          │   │
│  │   ┌─────────────────────┼───────────────────────────────────────┐  │   │
│  │   │              Private Subnets (3 AZs)                        │  │   │
│  │   │   ┌─────────┐  ┌─────────┐  ┌─────────┐                    │  │   │
│  │   │   │10.0.10.0│  │10.0.20.0│  │10.0.30.0│                    │  │   │
│  │   │   │  /24    │  │  /24    │  │  /24    │                    │  │   │
│  │   │   └────┬────┘  └────┬────┘  └────┬────┘                    │  │   │
│  │   │        │            │            │                          │  │   │
│  │   │   ┌────┴────────────┴────────────┴────┐                    │  │   │
│  │   │   │         EKS Cluster               │                    │  │   │
│  │   │   │  ┌─────────────────────────────┐  │                    │  │   │
│  │   │   │  │     Worker Node Group       │  │                    │  │   │
│  │   │   │  │  ┌─────┐ ┌─────┐ ┌─────┐   │  │                    │  │   │
│  │   │   │  │  │Node1│ │Node2│ │Node3│   │  │                    │  │   │
│  │   │   │  │  └─────┘ └─────┘ └─────┘   │  │                    │  │   │
│  │   │   │  └─────────────────────────────┘  │                    │  │   │
│  │   │   └───────────────────────────────────┘                    │  │   │
│  │   └────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         ECR Repositories                            │   │
│  │   ┌─────────────────────┐     ┌─────────────────────┐              │   │
│  │   │  shopdeploy-backend │     │ shopdeploy-frontend │              │   │
│  │   └─────────────────────┘     └─────────────────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         IAM Roles & Policies                        │   │
│  │   • EKS Cluster Role        • EKS Node Group Role                  │   │
│  │   • AWS Load Balancer Controller Role                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Resources Created by Module

#### 🌐 VPC Module (`modules/vpc/`)
| Resource | Description |
|----------|-------------|
| VPC | Virtual Private Cloud with DNS support |
| Internet Gateway | Internet access for public subnets |
| NAT Gateway(s) | Outbound internet for private subnets |
| Public Subnets (3) | For load balancers, bastion hosts |
| Private Subnets (3) | For EKS worker nodes (security) |
| Route Tables | Traffic routing rules |
| Security Groups | Network firewall rules |

#### 🔐 IAM Module (`modules/iam/`)
| Resource | Description |
|----------|-------------|
| EKS Cluster Role | Permissions for EKS control plane |
| EKS Node Role | Permissions for worker nodes |
| Service Account Roles | IRSA for AWS Load Balancer Controller |
| Policies | Least-privilege access policies |

#### 📦 ECR Module (`modules/ecr/`)
| Resource | Description |
|----------|-------------|
| Backend Repository | Docker images for Node.js API |
| Frontend Repository | Docker images for React app |
| Lifecycle Policies | Auto-cleanup old images (retain 30) |
| Image Scanning | Vulnerability scanning on push |

#### ☸️ EKS Module (`modules/eks/`)
| Resource | Description |
|----------|-------------|
| EKS Cluster | Managed Kubernetes control plane |
| Node Group | Auto-scaling worker nodes (t3.medium/large) |
| Add-ons | CoreDNS, kube-proxy, vpc-cni |
| OIDC Provider | For IAM Roles for Service Accounts |
| Cluster Autoscaler | Dynamic node scaling |
| Metrics Server | Resource metrics for HPA |
| AWS Load Balancer Controller | Ingress and service load balancers |

---

## 📋 Prerequisites

### Required Tools

```bash
# Terraform (v1.5.0+)
terraform --version

# AWS CLI (v2.x)
aws --version

# kubectl (v1.28+)
kubectl version --client

# Helm (v3.x) - for post-deployment
helm version
```

### AWS Configuration

```bash
# Configure AWS credentials
aws configure

# Verify credentials
aws sts get-caller-identity
```

### Required IAM Permissions

The user/role running Terraform needs these permissions:
- `AmazonVPCFullAccess`
- `AmazonEKSClusterPolicy`
- `AmazonEC2ContainerRegistryFullAccess`
- `IAMFullAccess` (or specific role creation permissions)

---

## 🚀 Quick Start

### Step 1: Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**terraform.tfvars:**
```hcl
# Project Configuration
project_name = "shopdeploy"
environment  = "prod"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = false  # Set true for cost savings in non-prod

# EKS Configuration
eks_cluster_version     = "1.29"
eks_node_instance_types = ["t3.medium", "t3.large"]
eks_node_desired_size   = 3
eks_node_min_size       = 2
eks_node_max_size       = 10
eks_node_disk_size      = 50

# ECR Configuration
ecr_image_retention_count = 30

# Domain
domain_name = "shopdeploy.com"
enable_ssl  = true
```

### Step 2: Initialize Terraform

```bash
# Initialize providers and modules
terraform init

# Or use the script
chmod +x ../scripts/terraform-init.sh
../scripts/terraform-init.sh prod
```

### Step 3: Plan Infrastructure

```bash
# Preview what will be created
terraform plan -out=tfplan

# Review the plan carefully!
```

### Step 4: Apply Infrastructure

```bash
# Create all resources
terraform apply tfplan

# Or auto-approve (use with caution)
terraform apply -auto-approve
```

### Step 5: Configure kubectl

```bash
# Update kubeconfig (command from terraform output)
aws eks update-kubeconfig --region us-east-1 --name shopdeploy-prod-eks

# Verify connection
kubectl get nodes

# Check cluster info
kubectl cluster-info
```

### Step 6: Deploy Application

After infrastructure is ready, deploy using the Jenkins pipeline:

```bash
# Option 1: Via Jenkins (Recommended)
# Push code to GitHub - Jenkins pipeline automatically deploys

# Option 2: Manual Helm deployment
helm upgrade --install shopdeploy-backend ./helm/backend \
  --namespace shopdeploy \
  --values ./helm/backend/values-dev.yaml

helm upgrade --install shopdeploy-frontend ./helm/frontend \
  --namespace shopdeploy \
  --values ./helm/frontend/values-dev.yaml
```

---

## 📁 Module Structure

```
terraform/
├── main.tf                    # Main configuration, module calls
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output value definitions
├── data.tf                    # Data sources (availability zones, etc.)
├── terraform.tfvars           # Your variable values (git-ignored)
├── terraform.tfvars.example   # Example variable values (commit this)
├── Makefile                   # Shortcuts: make plan, make apply
├── README.md                  # This documentation
│
├── backend-setup/             # S3 backend for remote state
│   └── ...                    # State bucket & DynamoDB lock table
│
├── environments/              # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
│
└── modules/                   # Reusable Terraform modules
    ├── vpc/                   # VPC networking module
    │   ├── main.tf            # VPC, subnets, NAT, IGW
    │   ├── variables.tf       # CIDR blocks, AZ config
    │   └── outputs.tf         # VPC ID, subnet IDs
    │
    ├── iam/                   # IAM roles and policies module
    │   ├── main.tf            # EKS cluster role, node role
    │   ├── variables.tf       # Role names, policies
    │   └── outputs.tf         # Role ARNs
    │
    ├── ecr/                   # Container registry module
    │   ├── main.tf            # ECR repos, lifecycle policies
    │   ├── variables.tf       # Repo names, retention
    │   └── outputs.tf         # Repository URLs
    │
    └── eks/                   # Kubernetes cluster module
        ├── main.tf            # EKS cluster, node groups, add-ons
        ├── variables.tf       # Instance types, scaling config
        └── outputs.tf         # Cluster endpoint, CA data
```

---

## ⚙️ Configuration

### Variable Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_name` | string | `shopdeploy` | Project name for resource naming |
| `environment` | string | `prod` | Environment (dev/staging/prod) |
| `aws_region` | string | `us-east-1` | AWS region for deployment |
| `vpc_cidr` | string | `10.0.0.0/16` | VPC CIDR block |
| `eks_cluster_version` | string | `1.29` | Kubernetes version |
| `eks_node_instance_types` | list | `["t3.medium"]` | EC2 instance types for nodes |
| `eks_node_desired_size` | number | `3` | Desired worker node count |
| `eks_node_min_size` | number | `2` | Minimum worker node count |
| `eks_node_max_size` | number | `10` | Maximum worker node count |
| `enable_nat_gateway` | bool | `true` | Enable NAT for private subnets |
| `single_nat_gateway` | bool | `false` | Use single NAT (cost saving) |

### Environment-Specific Configurations

**Development:**
```hcl
environment         = "dev"
eks_node_desired_size = 2
eks_node_min_size    = 1
eks_node_max_size    = 3
single_nat_gateway   = true  # Cost saving
```

**Staging:**
```hcl
environment         = "staging"
eks_node_desired_size = 2
eks_node_min_size    = 2
eks_node_max_size    = 5
single_nat_gateway   = true
```

**Production:**
```hcl
environment         = "prod"
eks_node_desired_size = 3
eks_node_min_size    = 3
eks_node_max_size    = 10
single_nat_gateway   = false  # High availability
```

---

## 📤 Outputs

After `terraform apply`, these outputs are available:

```bash
# View all outputs
terraform output

# Get specific output
terraform output eks_cluster_name
terraform output ecr_backend_url
terraform output configure_kubectl
```

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC identifier |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `eks_cluster_name` | EKS cluster name |
| `eks_cluster_endpoint` | Kubernetes API endpoint |
| `ecr_backend_url` | Backend ECR repository URL |
| `ecr_frontend_url` | Frontend ECR repository URL |
| `configure_kubectl` | Command to configure kubectl |
| `ecr_login_command` | Command to login to ECR |

---

## 💰 Cost Estimation

### Monthly Cost Breakdown (Approximate)

| Resource | Dev | Staging | Production |
|----------|-----|---------|------------|
| EKS Control Plane | $73 | $73 | $73 |
| EC2 Workers (t3.medium x3) | $90 | $90 | $120 |
| NAT Gateway | $32 | $32 | $96 (3x) |
| ECR Storage | $1 | $1 | $5 |
| Data Transfer | $10 | $20 | $50+ |
| **Total** | **~$206** | **~$216** | **~$344+** |

### Cost Optimization Tips

1. **Use single NAT in non-prod**: `single_nat_gateway = true`
2. **Scale down nodes off-hours**: Use Cluster Autoscaler
3. **Spot instances**: Configure spot instances for worker nodes
4. **Reserved capacity**: Purchase reserved instances for prod
5. **Destroy dev when idle**: `terraform destroy` at end of day

---

## 🛡️ Best Practices

### State Management

```hcl
# Enable remote state (recommended for teams)
terraform {
  backend "s3" {
    bucket         = "shopdeploy-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "shopdeploy-terraform-locks"
  }
}
```

### Security Best Practices

- ✅ Enable encryption for EBS volumes
- ✅ Use private subnets for worker nodes
- ✅ Enable VPC flow logs
- ✅ Use IAM roles (not access keys) for service accounts
- ✅ Enable ECR image scanning
- ✅ Restrict security group rules

### Operational Best Practices

- ✅ Always run `terraform plan` before `apply`
- ✅ Use workspaces for multiple environments
- ✅ Tag all resources for cost tracking
- ✅ Version pin providers
- ✅ Review state file changes in PRs

---

## 🔧 Troubleshooting

### Common Issues

**1. EKS cluster creation timeout**
```bash
# EKS takes 10-15 minutes to create
# Increase timeout if needed
terraform apply -parallelism=1
```

**2. IAM role not found**
```bash
# IAM propagation delay
# Wait a few seconds and retry
sleep 10 && terraform apply
```

**3. Subnet CIDR conflicts**
```bash
# Ensure no overlapping CIDRs
terraform plan  # Check for conflicts
```

**4. kubectl connection refused**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name shopdeploy-prod-eks

# Check cluster status
aws eks describe-cluster --name shopdeploy-prod-eks --query 'cluster.status'
```

### Destroy Infrastructure

```bash
# Destroy all resources (CAUTION!)
terraform destroy

# Destroy specific resource
terraform destroy -target=module.eks
```

---

## 🔄 CI/CD Integration

The Terraform-provisioned infrastructure integrates with the Jenkins pipeline:

### Infrastructure → Pipeline Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Terraform  │────▶│     ECR     │────▶│   Jenkins   │────▶│     EKS     │
│   (IaC)     │     │ Repositories│     │   Pipeline  │     │   Cluster   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

### Resources Used by Jenkins

| Resource | Created By | Used For |
|----------|------------|----------|
| EKS Cluster | Terraform | Kubernetes deployments |
| ECR Repos | Terraform | Docker image storage |
| IAM Roles | Terraform | EKS authentication |
| VPC/Subnets | Terraform | Network isolation |

---

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [EKS Workshop](https://www.eksworkshop.com/)

---

## 🤝 Contributing

1. Create a feature branch
2. Make changes to Terraform configurations
3. Run `terraform fmt` to format code
4. Run `terraform validate` to check syntax
5. Submit a pull request

---

<p align="center">
  <b>Infrastructure as Code for ShopDeploy</b><br>
  Made with ❤️ by the ShopDeploy DevOps Team
</p>
