---
name: argocd
description: >
  Argo CD GitOps continuous delivery for Kubernetes: argocd CLI, application
  creation and management, sync policies, auto-sync and self-heal, health checks,
  rollbacks, SSO integration, app-of-apps pattern, ApplicationSets, and
  multi-cluster deployment.
  MUST consult when installing, configuring, or troubleshooting argocd.
triggerPhrases:
  - "argocd"
  - "argo cd"
  - "Argo CD"
  - "argocd app"
  - "argocd sync"
  - "argocd rollback"
  - "gitops"
  - "GitOps"
  - "argocd login"
  - "ApplicationSet"
  - "app-of-apps"
  - "argocd cluster"
  - "argocd repo"
  - "argocd proj"
globs:
  - "**/applicationset*.yaml"
  - "**/applicationset*.yml"
  - "**/argocd-cm.yaml"
  - "**/argocd-rbac-cm.yaml"
last_verified: "2026-03"
---

## Identity

- **Binary**: `argocd` (CLI)
- **Server components**: `argocd-server`, `argocd-repo-server`, `argocd-application-controller`, `argocd-dex-server` (SSO), `argocd-redis`, `argocd-applicationset-controller`, `argocd-notifications-controller`
- **Namespace**: `argocd` (by convention)
- **Config**: ConfigMaps `argocd-cm`, `argocd-rbac-cm`, `argocd-cmd-params-cm` in the argocd namespace
- **Web UI**: port 443 (argocd-server Service, HTTPS)
- **API**: same as web UI; gRPC on port 443
- **Install CLI**: `brew install argocd` / `pacman -S argocd` / download from GitHub releases
- **Install server**: `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`

## Quick Start

```bash
# Install Argo CD in-cluster
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get initial admin password
argocd admin initial-password -n argocd

# Port-forward for local access
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Login
argocd login localhost:8080

# Create an application
argocd app create my-app \
  --repo https://github.com/example/repo.git \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Sync the application
argocd app sync my-app
```

## Key Operations

| Task | Command |
|------|---------|
| Login | `argocd login <server> [--username admin] [--password <pw>] [--insecure]` |
| Get initial password | `argocd admin initial-password -n argocd` |
| Change password | `argocd account update-password` |
| Create application | `argocd app create <name> --repo <url> --path <path> --dest-server <server> --dest-namespace <ns>` |
| Create from Helm chart | `argocd app create <name> --repo <chart-repo> --helm-chart <chart> --revision <version> --dest-server <server> --dest-namespace <ns>` |
| List applications | `argocd app list` |
| Get app details | `argocd app get <name>` |
| Sync application | `argocd app sync <name>` |
| Sync with prune | `argocd app sync <name> --prune` |
| Sync dry run | `argocd app sync <name> --dry-run` |
| App diff | `argocd app diff <name>` |
| Rollback | `argocd app rollback <name> [revision-id]` |
| View history | `argocd app history <name>` |
| Delete application | `argocd app delete <name> [--cascade]` |
| View pod logs | `argocd app logs <name>` |
| Enable auto-sync | `argocd app set <name> --sync-policy automated` |
| Enable self-heal | `argocd app set <name> --self-heal` |
| Enable auto-prune | `argocd app set <name> --auto-prune` |
| Add Git repo | `argocd repo add <url> [--username <u>] [--password <p>]` |
| Add Helm repo | `argocd repo add <url> --type helm --name <name>` |
| List repos | `argocd repo list` |
| Add cluster | `argocd cluster add <context-name>` |
| List clusters | `argocd cluster list` |
| Create project | `argocd proj create <name>` |
| Add project destination | `argocd proj add-destination <project> <server> <namespace>` |
| Add project source | `argocd proj add-source <project> <repo-url>` |
| Check permissions | `argocd account can-i <verb> <resource>` |
| Version info | `argocd version` |

## Expected Ports

- **443/tcp** -- Argo CD server (web UI + API + gRPC)
- **8080/tcp** -- Argo CD server (HTTP, when running without TLS termination)
- **8081/tcp** -- Argo CD metrics
- **8082/tcp** -- Repo server metrics
- Verify: `kubectl get svc -n argocd`

## Health Checks

1. `kubectl get pods -n argocd` -> all pods Running/Ready
2. `argocd version` -> shows both client and server versions
3. `argocd app list` -> returns applications without connection error
4. `kubectl get applications -n argocd` -> shows Synced/Healthy status

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `rpc error: transport is closing` | Server not ready or TLS mismatch | Wait for pods; use `--insecure` for self-signed certs; check `--grpc-web` |
| App stuck in `Unknown` health | Custom resource without health check | Add custom health check Lua script in `argocd-cm` ConfigMap |
| App `OutOfSync` but won't auto-sync | Auto-sync not enabled or already attempted this commit | `argocd app set <name> --sync-policy automated --self-heal`; check `argocd app get <name>` for sync errors |
| Sync failed: `ComparisonError` | Repo unreachable or invalid manifests | `argocd repo list` to verify repo; `argocd app get <name> --hard-refresh` |
| `permission denied` on sync | RBAC policy blocking the action | Check `argocd-rbac-cm` ConfigMap; `argocd account can-i sync applications` |
| `Failed to load target state` | Helm chart version not found or values error | Check chart version exists; `argocd app get <name>` for detailed error |
| App shows `Degraded` health | Kubernetes resource in failed state | Check pod events: `kubectl describe pod <pod> -n <ns>`; fix the underlying resource issue |
| ApplicationSet not generating apps | Generator config error or missing permissions | `kubectl logs -n argocd deploy/argocd-applicationset-controller`; verify generator spec |

## Pain Points

- **Automated sync won't retry the same commit.** Once Argo CD attempts to sync a specific commit+parameter combination and fails, it won't retry automatically. You must either push a new commit, manually sync, or enable the `retry` policy with `refresh: true`.
- **Rollback is disabled with auto-sync.** When automated sync is active, Argo CD will immediately re-sync to the Git state after a rollback. To roll back, disable auto-sync first, rollback, fix the issue in Git, then re-enable auto-sync.
- **Self-heal timeout is 5 seconds by default.** If someone manually edits a resource in the cluster, Argo CD detects the drift and resyncs within 5 seconds when `selfHeal: true`. This is aggressive; the default reconciliation interval is 120 seconds (with 60-second jitter) for detecting new Git commits.
- **App-of-apps vs ApplicationSets.** The app-of-apps pattern uses a parent Application whose manifests directory contains child Application resources. ApplicationSets use generators (List, Cluster, Git, Matrix, Merge, SCM Provider, Pull Request) to template applications dynamically. ApplicationSets are more scalable for multi-cluster and multi-environment setups.
- **RBAC uses Casbin policies.** Argo CD's RBAC model is defined in the `argocd-rbac-cm` ConfigMap using Casbin policy syntax: `p, <role>, <resource>, <action>, <object>`. The default policy grants admin access. Lock this down for production.
- **SSO is via Dex or OIDC directly.** Argo CD bundles Dex as an identity broker, supporting LDAP, SAML, GitHub, GitLab, and generic OIDC providers. Configure in the `argocd-cm` ConfigMap under `dex.config` or `oidc.config`.

## See Also

- **kubernetes** -- Cluster management and kubectl operations; Argo CD deploys to Kubernetes clusters
- **helm** -- Chart-based Kubernetes packaging; Argo CD natively supports Helm chart sources
- **terraform** -- Infrastructure provisioning; complementary to Argo CD (infra vs app deployment)

## References

See `references/` for:
- `common-patterns.md` -- app-of-apps setup, ApplicationSet generators, sync policies, RBAC configuration, SSO setup, multi-cluster patterns
- `docs.md` -- official documentation links
