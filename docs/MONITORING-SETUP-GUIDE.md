# Prometheus & Grafana Monitoring Setup Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Grafana Server Installation](#grafana-server-installation)
4. [Prometheus Installation](#prometheus-installation)
5. [Node Exporter Installation](#node-exporter-installation)
6. [Kubernetes Installation (Helm)](#kubernetes-installation-helm)
7. [Custom Dashboards](#custom-dashboards)
8. [Alerting Configuration](#alerting-configuration)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The ShopDeploy monitoring stack includes:
- **Grafana**: Visualization and dashboards (Port 3000)
- **Prometheus**: Metrics collection and storage (Port 9090)
- **Node Exporter**: Host-level metrics (Port 9100)
- **Alertmanager**: Alert routing and notifications

### Environment Requirements

| Component | Instance Type | Ports | Storage |
|-----------|--------------|-------|---------|
| Grafana Server | t3.medium | 3000, 9090, 9100 | 20GB SSD |
| Prometheus | t3.medium | 9090 | 50GB SSD |
| Node Exporter | Any | 9100 | - |

---

## Prerequisites

- AWS EC2 Instance: Amazon Linux 2 / Amazon Linux 2023
- Security Group Inbound Rules:
  - Port 3000 (Grafana)
  - Port 9090 (Prometheus)
  - Port 9100 (Node Exporter)

---

## Grafana Server Installation

### Step 1: Update System and Install Dependencies

```bash
sudo yum update -y
sudo yum install wget tar -y
sudo yum install make -y
```

### Step 2: Install Grafana Enterprise

```bash
# Install Grafana Enterprise 12.2.1
sudo yum install -y https://dl.grafana.com/enterprise/release/grafana-enterprise-12.2.1-1.x86_64.rpm

# Start Grafana service
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
sudo systemctl status grafana-server

# Verify installation
grafana-server --version
```

### Step 3: Access Grafana Web UI

Open in browser:
```
http://<EC2-PUBLIC-IP>:3000
```

**Default Credentials:**
- Username: `admin`
- Password: `admin`

You will be prompted to change the password on first login. Set a secure password (e.g., `Khushal@41`).

---

## Prometheus Installation

### Step 1: Download Prometheus

```bash
# Download Prometheus 3.5.0 (Linux AMD64)
cd ~
wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz

# Extract archive
sudo tar -xvf prometheus-3.5.0.linux-amd64.tar.gz
sudo mv prometheus-3.5.0.linux-amd64 prometheus
```

### Step 2: Create Prometheus User

```bash
# Create prometheus user (no login shell)
sudo useradd --no-create-home --shell /bin/false prometheus

# Verify user creation (optional)
id prometheus
sudo cat /etc/passwd | grep prometheus
```

### Step 3: Setup Prometheus Directories and Files

```bash
cd ~/prometheus

# Copy binaries to /usr/local/bin
sudo cp -r prometheus /usr/local/bin/
sudo cp -r promtool /usr/local/bin/

# Create configuration and data directories
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

# Copy configuration file
sudo cp prometheus.yml /etc/prometheus/

# Set ownership
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
```

### Step 4: Create Systemd Service

```bash
sudo nano /etc/systemd/system/prometheus.service
```

Paste the following:

```ini
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
```

Save and exit (Ctrl+X, Y, Enter).

### Step 5: Start Prometheus Service

```bash
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
sudo systemctl status prometheus
```

### Step 6: Access Prometheus UI

Open in browser:
```
http://<EC2-PUBLIC-IP>:9090
```

---

## Node Exporter Installation

Node Exporter collects hardware and OS metrics from the host.

### Step 1: Download Node Exporter

```bash
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.10.2/node_exporter-1.10.2.linux-amd64.tar.gz

# Extract archive
tar xvf node_exporter-1.10.2.linux-amd64.tar.gz
cd node_exporter-1.10.2.linux-amd64
```

### Step 2: Setup Node Exporter

```bash
# Copy binary to /usr/local/bin
sudo cp node_exporter /usr/local/bin

# Create node_exporter user
sudo useradd node_exporter --no-create-home --shell /bin/false

# Set ownership
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

### Step 3: Create Systemd Service

```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Paste the following:

```ini
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

Save and exit.

### Step 4: Start Node Exporter Service

```bash
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
sudo systemctl status node_exporter
```

### Step 5: Access Node Exporter Metrics

Open in browser:
```
http://<EC2-PUBLIC-IP>:9100/metrics
```

---

## Configure Prometheus to Scrape Node Exporter

Edit Prometheus configuration to add Node Exporter as a target:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Add the following under `scrape_configs`:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
```

Restart Prometheus:

```bash
sudo systemctl restart prometheus
```

---

## Configure Grafana Data Source

1. Login to Grafana at `http://<EC2-PUBLIC-IP>:3000`
2. Go to **Configuration → Data Sources → Add data source**
3. Select **Prometheus**
4. Set URL: `http://localhost:9090`
5. Click **Save & Test**

---

## Kubernetes Installation (Helm)

For Kubernetes/EKS deployments, use Helm charts:

### Add Helm Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Install Prometheus on Kubernetes

```bash
kubectl create namespace monitoring

helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --values monitoring/prometheus-values.yaml \
    --wait --timeout 10m
```

### Install Grafana on Kubernetes

```bash
helm upgrade --install grafana grafana/grafana \
    --namespace monitoring \
    --values monitoring/grafana-values.yaml \
    --set adminPassword="Khushal@41" \
    --wait --timeout 10m
```

### Access Kubernetes Monitoring

```bash
# Port forward Grafana
kubectl port-forward svc/grafana 3000:80 -n monitoring &

# Port forward Prometheus
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring &

# Get Grafana admin password
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Useful PromQL Queries

```promql
# Request rate by service
rate(http_requests_total{namespace="shopdeploy"}[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Memory usage by pod
container_memory_usage_bytes{namespace="shopdeploy"} / 1024 / 1024

# CPU usage percentage
rate(container_cpu_usage_seconds_total{namespace="shopdeploy"}[5m]) * 100

# Error rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100
```

---

### Access Grafana

```bash
# Get Grafana URL (LoadBalancer)
kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Or port forward
kubectl port-forward svc/grafana 3000:80 -n monitoring

# Get admin password (if not set)
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Login Credentials
- **Username**: admin
- **Password**: (set during installation or retrieve from secret)

### Pre-configured Data Sources

| Data Source | Type | URL |
|-------------|------|-----|
| Prometheus | prometheus | http://prometheus-server:80 |
| CloudWatch | cloudwatch | AWS SDK |

### Import Dashboards

The following dashboards are pre-configured:

| Dashboard | ID | Description |
|-----------|-----|-------------|
| Kubernetes Cluster | 7249 | Cluster overview |
| Node Exporter | 1860 | Host metrics |
| Kubernetes Pods | 6417 | Pod metrics |
| ShopDeploy Custom | - | Application metrics |

#### Import Additional Dashboards

1. Go to **Dashboards → Import**
2. Enter dashboard ID from [Grafana Dashboard Gallery](https://grafana.com/grafana/dashboards/)
3. Select **Prometheus** as data source
4. Click **Import**

---

## Custom Dashboards

### ShopDeploy Application Dashboard

The custom dashboard at [monitoring/dashboards/shopdeploy-dashboard.json](../monitoring/dashboards/shopdeploy-dashboard.json) includes:

#### Panels
1. **API Overview**
   - Total requests
   - Request rate
   - Error rate
   - Average response time

2. **Backend Metrics**
   - HTTP requests by endpoint
   - Response time distribution
   - Active connections
   - Database query performance

3. **Frontend Metrics**
   - Page load time
   - Asset load times
   - Client errors

4. **Infrastructure**
   - Pod CPU usage
   - Pod memory usage
   - Network I/O
   - Disk usage

### Install Custom Dashboard

```bash
# Create ConfigMap for dashboard
kubectl create configmap shopdeploy-dashboard \
    --from-file=monitoring/dashboards/shopdeploy-dashboard.json \
    --namespace monitoring \
    --dry-run=client -o yaml | kubectl apply -f -

# Label for Grafana sidecar to pick up
kubectl label configmap shopdeploy-dashboard grafana_dashboard=1 -n monitoring --overwrite
```

---

## Alerting Configuration

### Slack Integration

1. Create Slack Incoming Webhook
2. Update prometheus-values.yaml:

```yaml
alertmanager:
  config:
    global:
      slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
```

### Pre-configured Alert Rules

Add to prometheus-values.yaml `serverFiles.alerting_rules.yml`:

```yaml
groups:
  - name: shopdeploy-alerts
    rules:
      # High Error Rate
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{namespace="shopdeploy",status=~"5.."}[5m]) 
          / rate(http_requests_total{namespace="shopdeploy"}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 5% for the last 5 minutes"

      # High Latency
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="shopdeploy"}[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "95th percentile latency is above 1 second"

      # Pod Not Ready
      - alert: PodNotReady
        expr: |
          kube_pod_status_ready{namespace="shopdeploy",condition="true"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod not ready"
          description: "Pod {{ $labels.pod }} has been not ready for 5 minutes"

      # High Memory Usage
      - alert: HighMemoryUsage
        expr: |
          container_memory_usage_bytes{namespace="shopdeploy"} 
          / container_spec_memory_limit_bytes{namespace="shopdeploy"} > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Container memory usage is above 85%"

      # High CPU Usage
      - alert: HighCPUUsage
        expr: |
          rate(container_cpu_usage_seconds_total{namespace="shopdeploy"}[5m]) 
          / container_spec_cpu_quota{namespace="shopdeploy"} * 100000 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "Container CPU usage is above 80%"
```

### Test Alerts

```bash
# Trigger a test alert
kubectl exec -it deploy/prometheus-server -n monitoring -- \
  promtool test rules /etc/config/alerting_rules.yml
```

---

## Metrics Server Setup

For HPA to work, install Metrics Server:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl top nodes
kubectl top pods -n shopdeploy
```

---

## Troubleshooting

### Common Issues

#### 1. Prometheus Not Scraping Targets

```bash
# Check service discovery
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
# Navigate to Status → Targets

# Verify pod annotations
kubectl get pods -n shopdeploy -o yaml | grep -A 5 annotations
```

#### 2. Grafana Can't Connect to Prometheus

```bash
# Test connectivity
kubectl exec -it deploy/grafana -n monitoring -- curl http://prometheus-server:80/api/v1/query?query=up

# Check service
kubectl get svc prometheus-server -n monitoring
```

#### 3. No Data in Dashboards

```bash
# Check Prometheus is collecting data
curl "http://localhost:9090/api/v1/query?query=up"

# Verify time range in Grafana (last 5 minutes might be empty)
```

#### 4. Persistent Volume Issues

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Describe PVC for errors
kubectl describe pvc prometheus-server -n monitoring
```

### Useful Commands

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# View Prometheus logs
kubectl logs -l app=prometheus,component=server -n monitoring

# View Grafana logs
kubectl logs -l app.kubernetes.io/name=grafana -n monitoring

# Check Alertmanager status
kubectl exec -it deploy/prometheus-alertmanager -n monitoring -- amtool config show
```

---

## Upgrade Monitoring Stack

```bash
# Update Helm repos
helm repo update

# Upgrade Prometheus
helm upgrade prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --values monitoring/prometheus-values.yaml

# Upgrade Grafana
helm upgrade grafana grafana/grafana \
    --namespace monitoring \
    --values monitoring/grafana-values.yaml
```

---

## Cleanup

```bash
# Uninstall monitoring stack
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring

# Delete namespace (removes everything)
kubectl delete namespace monitoring
```

---

## Next Steps

1. [Configure Jenkins Pipeline](./JENKINS-SETUP-GUIDE.md)
2. [Set up Helm Charts](./HELM-SETUP-GUIDE.md)
3. [Review Kubernetes Manifests](../k8s/README.md)
