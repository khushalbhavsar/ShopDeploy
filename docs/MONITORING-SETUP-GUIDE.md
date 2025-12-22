# Prometheus & Grafana Monitoring Setup Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Installation](#quick-installation)
4. [Prometheus Setup](#prometheus-setup)
5. [Grafana Setup](#grafana-setup)
6. [Custom Dashboards](#custom-dashboards)
7. [Alerting Configuration](#alerting-configuration)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The ShopDeploy monitoring stack includes:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notifications
- **Node Exporter**: Host-level metrics
- **Kube State Metrics**: Kubernetes object metrics

### Architecture
```
┌─────────────────────────────────────────────────────────────────────┐
│                     Monitoring Architecture                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐       │
│   │  ShopDeploy  │────▶│  Prometheus  │────▶│   Grafana    │       │
│   │   Backend    │     │   Server     │     │  Dashboard   │       │
│   └──────────────┘     └──────────────┘     └──────────────┘       │
│                              │                                       │
│   ┌──────────────┐           │              ┌──────────────┐       │
│   │  ShopDeploy  │───────────┤              │ Alertmanager │       │
│   │   Frontend   │           │              │    (Slack)   │       │
│   └──────────────┘           │              └──────────────┘       │
│                              │                      ▲               │
│   ┌──────────────┐           │                      │               │
│   │ Node Exporter│───────────┤                      │               │
│   └──────────────┘           │              Alert Rules             │
│                              ▼                                       │
│   ┌──────────────┐     ┌──────────────┐                            │
│   │ Kube State   │────▶│   Storage    │                            │
│   │   Metrics    │     │  (50GB PV)   │                            │
│   └──────────────┘     └──────────────┘                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- Kubernetes cluster (EKS) running
- kubectl configured
- Helm 3.x installed
- Persistent storage available (EBS, etc.)

---

## Quick Installation

### One-Command Installation

```bash
# Set namespace and run installer
export GRAFANA_ADMIN_PASSWORD="your-secure-password"
chmod +x monitoring/install-monitoring.sh
./monitoring/install-monitoring.sh monitoring
```

### Manual Installation Steps

```bash
# 1. Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 2. Create namespace
kubectl create namespace monitoring

# 3. Install Prometheus
helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --values monitoring/prometheus-values.yaml \
    --wait --timeout 10m

# 4. Install Grafana
helm upgrade --install grafana grafana/grafana \
    --namespace monitoring \
    --values monitoring/grafana-values.yaml \
    --set adminPassword="your-secure-password" \
    --wait --timeout 10m
```

---

## Prometheus Setup

### Configuration Overview

The [prometheus-values.yaml](../monitoring/prometheus-values.yaml) configures:

| Component | Enabled | Storage | Purpose |
|-----------|---------|---------|---------|
| Prometheus Server | ✅ | 50Gi | Main metrics storage |
| Alertmanager | ✅ | 10Gi | Alert routing |
| Node Exporter | ✅ | - | Host metrics |
| Kube State Metrics | ✅ | - | K8s object metrics |
| Push Gateway | ❌ | - | Batch job metrics |

### Scrape Configuration

Prometheus automatically discovers pods with these annotations:

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "5000"
  prometheus.io/path: "/api/health/metrics"
```

### Verify Prometheus Installation

```bash
# Check pods
kubectl get pods -n monitoring -l app=prometheus

# Port forward to access UI
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring

# Access at http://localhost:9090
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

## Grafana Setup

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
