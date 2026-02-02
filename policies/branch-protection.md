# 🔒 Branch Protection Policy

## Overview

This document defines the branch protection rules and merge requirements for the ShopDeploy repository.

---

## Protected Branches

| Branch | Protection Level | Purpose |
|--------|-----------------|---------|
| `main` | **Highest** | Production-ready code |
| `staging` | **High** | Pre-production testing |
| `develop` | **Medium** | Integration branch |

---

## Branch Protection Rules

### `main` Branch (Production)

```yaml
Protection Rules:
  require_pull_request: true
  required_approving_reviews: 2
  require_code_owner_reviews: true
  dismiss_stale_reviews: true
  require_status_checks: true
  required_status_checks:
    - CI Pipeline (Build)
    - CI Pipeline (Tests)
    - CI Pipeline (Security Scan)
    - SonarQube Quality Gate
  require_branches_up_to_date: true
  enforce_admins: true
  allow_force_pushes: false
  allow_deletions: false
```

### `staging` Branch

```yaml
Protection Rules:
  require_pull_request: true
  required_approving_reviews: 1
  require_status_checks: true
  required_status_checks:
    - CI Pipeline (Build)
    - CI Pipeline (Tests)
  require_branches_up_to_date: true
  allow_force_pushes: false
```

### `develop` Branch

```yaml
Protection Rules:
  require_pull_request: true
  required_approving_reviews: 1
  require_status_checks: true
  required_status_checks:
    - CI Pipeline (Build)
  allow_force_pushes: false
```

---

## Merge Requirements

### For Production (`main`)

1. ✅ All CI checks passing
2. ✅ 2 approved reviews (including 1 code owner)
3. ✅ SonarQube Quality Gate passed
4. ✅ Security scan completed (no CRITICAL vulnerabilities)
5. ✅ Staging deployment verified
6. ✅ Branch up-to-date with main

### For Staging

1. ✅ All CI checks passing
2. ✅ 1 approved review
3. ✅ Dev deployment verified

### For Develop

1. ✅ Build passing
2. ✅ 1 approved review

---

## Code Owners

```
# .github/CODEOWNERS

# Global owners
* @devops-team @tech-leads

# Backend
/shopdeploy-backend/ @backend-team

# Frontend
/shopdeploy-frontend/ @frontend-team

# Infrastructure
/terraform/ @devops-team @sre-team
/helm/ @devops-team
/ci-cd/ @devops-team

# Critical files
/VERSION @tech-leads
/policies/ @tech-leads @devops-team
```

---

## Branch Naming Convention

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<ticket>-<description>` | `feature/SHOP-123-add-payment` |
| Bugfix | `bugfix/<ticket>-<description>` | `bugfix/SHOP-456-fix-cart` |
| Hotfix | `hotfix/<ticket>-<description>` | `hotfix/SHOP-789-security-patch` |
| Release | `release/v<version>` | `release/v1.2.0` |

---

## Enforcement

- Branch protection rules are enforced via GitHub/GitLab settings
- CI pipeline validates branch naming convention
- Automated notifications for policy violations

---

*Last Updated: February 2026*
