# 🔄 Rollback Strategy

## Overview

This document defines the rollback procedures for ShopDeploy to ensure rapid recovery from failed deployments.

---

## Rollback Triggers

### Automatic Rollback

The CD pipeline automatically initiates rollback when:

| Trigger | Condition | Action |
|---------|-----------|--------|
| Smoke Test Failure | Pod health check fails | Helm rollback to previous revision |
| Deployment Timeout | Rollout exceeds 10 minutes | Helm rollback |
| Critical Errors | Error rate > 5% within 5 minutes | Helm rollback |

### Manual Rollback

Initiated by DevOps/SRE team when:

- Performance degradation detected
- Security vulnerability discovered
- Business-critical bug reported
- Customer-impacting issues

---

## Rollback Methods

### Method 1: Helm Rollback (Recommended)

```bash
# List release history
helm history shopdeploy-backend -n shopdeploy

# Rollback to previous revision
helm rollback shopdeploy-backend -n shopdeploy

# Rollback to specific revision
helm rollback shopdeploy-backend 5 -n shopdeploy --wait --timeout 5m

# Rollback frontend
helm rollback shopdeploy-frontend -n shopdeploy --wait --timeout 5m
```

### Method 2: CD Pipeline Rollback

```bash
# Trigger CD pipeline with previous IMAGE_TAG
# Jenkins > shopdeploy-cd > Build with Parameters
# IMAGE_TAG: <previous-tag>  (e.g., 41-abc1234)
# ENVIRONMENT: prod
```

### Method 3: kubectl Rollback (Emergency)

```bash
# Rollback deployment to previous revision
kubectl rollout undo deployment/shopdeploy-backend -n shopdeploy
kubectl rollout undo deployment/shopdeploy-frontend -n shopdeploy

# Rollback to specific revision
kubectl rollout undo deployment/shopdeploy-backend --to-revision=3 -n shopdeploy

# Verify rollback status
kubectl rollout status deployment/shopdeploy-backend -n shopdeploy
```

---

## Rollback Decision Matrix

| Severity | Impact | Response Time | Rollback Method |
|----------|--------|---------------|-----------------|
| **P1 - Critical** | Service down | < 5 minutes | Automatic + Manual verification |
| **P2 - High** | Major feature broken | < 15 minutes | CD Pipeline rollback |
| **P3 - Medium** | Minor feature affected | < 1 hour | Helm rollback |
| **P4 - Low** | Cosmetic issues | Next release | Hotfix in next deployment |

---

## Rollback Procedure

### Step 1: Incident Detection

```
┌─────────────────────────────────────────────────────────────┐
│                   INCIDENT DETECTED                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   Monitoring Alert    Customer Report    Smoke Test Fail    │
│         │                   │                   │           │
│         └───────────────────┼───────────────────┘           │
│                             ▼                                │
│                    ┌───────────────┐                        │
│                    │ Assess Impact │                        │
│                    └───────┬───────┘                        │
│                            │                                 │
│              ┌─────────────┼─────────────┐                  │
│              ▼             ▼             ▼                  │
│         ┌────────┐   ┌────────┐   ┌────────┐               │
│         │   P1   │   │   P2   │   │ P3/P4  │               │
│         │Critical│   │  High  │   │Med/Low │               │
│         └───┬────┘   └───┬────┘   └───┬────┘               │
│             │            │            │                     │
│             ▼            ▼            ▼                     │
│         IMMEDIATE    < 15 MIN     SCHEDULED                 │
│         ROLLBACK     ROLLBACK      HOTFIX                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Step 2: Execute Rollback

```bash
# 1. Notify team
# Post in #incidents Slack channel

# 2. Identify last stable version
helm history shopdeploy-backend -n shopdeploy

# 3. Execute rollback
helm rollback shopdeploy-backend -n shopdeploy --wait
helm rollback shopdeploy-frontend -n shopdeploy --wait

# 4. Verify rollback
kubectl get pods -n shopdeploy
kubectl rollout status deployment/shopdeploy-backend -n shopdeploy
```

### Step 3: Post-Rollback Verification

```bash
# Check pod status
kubectl get pods -n shopdeploy -o wide

# Check service endpoints
kubectl get svc -n shopdeploy

# Run smoke tests
./scripts/kubernetes/smoke-test.sh

# Verify in monitoring
# - Check Grafana dashboard
# - Verify error rates normalized
# - Confirm response times stable
```

### Step 4: Incident Documentation

Create incident report with:

- [ ] Timeline of events
- [ ] Root cause analysis
- [ ] Rollback execution details
- [ ] Recovery verification
- [ ] Preventive measures

---

## Rollback Automation in CD Pipeline

The CD pipeline (`Jenkinsfile-cd`) includes automatic rollback:

```groovy
// Captured before deployment
env.BACKEND_REVISION = <previous-revision>
env.FRONTEND_REVISION = <previous-revision>

// On failure, auto-rollback executes:
post {
    failure {
        sh '''
            helm rollback shopdeploy-backend ${BACKEND_REVISION} -n ${K8S_NAMESPACE}
            helm rollback shopdeploy-frontend ${FRONTEND_REVISION} -n ${K8S_NAMESPACE}
        '''
    }
}
```

---

## Rollback Limitations

| Scenario | Limitation | Mitigation |
|----------|------------|------------|
| Database migrations | Cannot auto-rollback schema changes | Use backward-compatible migrations |
| Data corruption | Rollback doesn't restore data | Point-in-time database recovery |
| Third-party APIs | External changes not rollbackable | Feature flags for integrations |
| Config changes | ConfigMaps may need manual revert | Version ConfigMaps with releases |

---

## Communication Template

### Slack Notification

```
🚨 PRODUCTION ROLLBACK INITIATED

Environment: Production
Previous Version: v1.5.0 (42-abc1234)
Rolled Back To: v1.4.2 (41-def5678)
Reason: Smoke test failure - Backend pods not healthy
Status: In Progress

Incident Commander: @devops-oncall
ETA: 5 minutes

Thread for updates 👇
```

### Post-Rollback Notification

```
✅ ROLLBACK COMPLETE

Environment: Production
Restored Version: v1.4.2 (41-def5678)
Rollback Duration: 3 minutes
Service Status: Healthy

📋 Post-mortem scheduled for tomorrow 10:00 AM
```

---

## Emergency Contacts

| Role | Contact | Escalation |
|------|---------|------------|
| DevOps On-Call | @devops-oncall | Immediate |
| SRE Lead | @sre-lead | If on-call unavailable |
| Engineering Manager | @eng-manager | P1 incidents |
| VP Engineering | @vp-eng | Extended outages |

---

*Last Updated: February 2026*
