# 🚀 Release Strategy

## Overview

This document defines the release management strategy for ShopDeploy, following semantic versioning and GitOps principles.

---

## Versioning

### Semantic Versioning (SemVer)

```
MAJOR.MINOR.PATCH

Example: 1.4.2
         │ │ │
         │ │ └── Patch: Bug fixes, security patches
         │ └──── Minor: New features, backward compatible
         └────── Major: Breaking changes
```

### Version File

The current version is maintained in the `VERSION` file at repository root.

```bash
# Read current version
cat VERSION
# Output: 1.0.0
```

### Git Tags

All releases are tagged with semantic version:

```bash
git tag -a v1.4.2 -m "Release v1.4.2: Add payment gateway"
git push origin v1.4.2
```

---

## Release Types

### 🟢 Patch Release (x.x.PATCH)

**Trigger:** Bug fixes, security patches

**Process:**
1. Create `hotfix/` branch from `main`
2. Fix issue
3. Update VERSION file (bump patch)
4. PR to `main` (requires 2 approvals)
5. Tag release
6. Auto-deploy to production

**Example:** `1.4.1` → `1.4.2`

---

### 🟡 Minor Release (x.MINOR.0)

**Trigger:** New features (backward compatible)

**Process:**
1. Features merged to `develop`
2. Create `release/v1.5.0` branch
3. QA testing in staging
4. Update VERSION file
5. PR to `main` (requires 2 approvals)
6. Tag release
7. Deploy to production

**Example:** `1.4.2` → `1.5.0`

---

### 🔴 Major Release (MAJOR.0.0)

**Trigger:** Breaking changes, major refactoring

**Process:**
1. Architecture review required
2. Extended QA period
3. Migration guide documentation
4. Stakeholder sign-off
5. Staged rollout (canary deployment)
6. Full deployment after validation

**Example:** `1.5.0` → `2.0.0`

---

## Release Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    RELEASE WORKFLOW                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐     ┌──────────┐     ┌──────────┐            │
│  │ develop  │────▶│ staging  │────▶│   main   │            │
│  │          │     │          │     │          │            │
│  │ (daily)  │     │ (weekly) │     │(release) │            │
│  └──────────┘     └──────────┘     └────┬─────┘            │
│                                         │                   │
│                                         ▼                   │
│                                    ┌──────────┐            │
│                                    │   Tag    │            │
│                                    │  v1.4.2  │            │
│                                    └────┬─────┘            │
│                                         │                   │
│                   ┌─────────────────────┼──────────────┐   │
│                   ▼                     ▼              ▼   │
│              ┌────────┐           ┌────────┐     ┌────────┐│
│              │  Dev   │           │Staging │     │  Prod  ││
│              │Cluster │           │Cluster │     │Cluster ││
│              └────────┘           └────────┘     └────────┘│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Environment Promotion

| Environment | Trigger | Approval | Rollback |
|-------------|---------|----------|----------|
| **Dev** | Push to `develop` | Automatic | Automatic |
| **Staging** | Merge to `staging` | 1 approval | Manual |
| **Production** | Tag `v*` on `main` | 2 approvals | Automatic |

---

## Release Checklist

### Pre-Release

- [ ] All tests passing
- [ ] Security scan completed
- [ ] VERSION file updated
- [ ] CHANGELOG.md updated
- [ ] Documentation updated
- [ ] Staging deployment verified

### Release

- [ ] PR approved (2 reviewers)
- [ ] Merged to main
- [ ] Git tag created
- [ ] Release notes published

### Post-Release

- [ ] Production deployment successful
- [ ] Smoke tests passing
- [ ] Monitoring alerts verified
- [ ] Stakeholders notified

---

## Changelog Format

```markdown
# Changelog

## [1.5.0] - 2026-02-15

### Added
- Payment gateway integration (#123)
- Order tracking feature (#145)

### Changed
- Updated cart UI for mobile (#156)

### Fixed
- Cart calculation bug (#167)

### Security
- Updated dependencies (#178)
```

---

## Rollback Policy

If a release causes issues:

1. **Automatic Rollback:** CD pipeline auto-rollbacks on smoke test failure
2. **Manual Rollback:** Use `helm rollback` or CD pipeline with previous tag
3. **Hotfix:** Create `hotfix/` branch for immediate fixes

See [rollback-strategy.md](./rollback-strategy.md) for detailed procedures.

---

*Last Updated: February 2026*
