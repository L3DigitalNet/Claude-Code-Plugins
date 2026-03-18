---
name: kubernetes-stack
description: >
  Production Kubernetes platform — cluster deployment, Helm package management,
  ArgoCD GitOps delivery, private container registry, and etcd administration.
  How the components connect for a self-managed Kubernetes platform.
  MUST consult when installing, configuring, or troubleshooting the Kubernetes platform stack.
triggerPhrases:
  - "Kubernetes platform"
  - "Kubernetes stack"
  - "production Kubernetes"
  - "K8s setup"
  - "Kubernetes GitOps"
  - "self-managed Kubernetes"
  - "Kubernetes with ArgoCD"
  - "deploy Kubernetes"
last_verified: "2026-03"
---

## Overview

A self-managed Kubernetes platform combines five components. Each handles a distinct layer of the platform; together they provide cluster orchestration, package management, GitOps-driven delivery, and image distribution.

```
   ┌────────────┐        ┌────────────────┐
   │ Developer  │        │  CI Pipeline   │
   └─────┬──────┘        └───────┬────────┘
         │  git push             │  docker push
         │                       │
   ┌─────▼──────┐     ┌─────────▼──────────┐
   │  Git Repo  │     │ Container Registry │
   │ (manifests │     │  (OCI images)      │
   │  + charts) │     │  :5000 or :443     │
   └─────┬──────┘     └─────────┬──────────┘
         │                       │
         │  watches              │  imagePull
         │                       │
   ┌─────▼──────────────────────▼──────────┐
   │              ArgoCD                    │
   │  (GitOps controller inside K8s)        │
   │  syncs desired state → cluster state   │
   └─────────────────┬────────────────────-─┘
                     │  kubectl apply
                     │
   ┌─────────────────▼────────────────────-─┐
   │          Kubernetes Cluster             │
   │  ┌─────────────────────────────────┐   │
   │  │  Control Plane (API server,     │   │
   │  │  scheduler, controller-manager) │   │
   │  │         ▲                       │   │
   │  │         │ etcd (cluster state)  │   │
   │  └─────────┴───────────────────────┘   │
   │  ┌──────┐  ┌──────┐  ┌──────┐         │
   │  │Node 1│  │Node 2│  │Node 3│  ...     │
   │  │(pods)│  │(pods)│  │(pods)│          │
   │  └──────┘  └──────┘  └──────┘          │
   └────────────────────────────────────────┘
                     ▲
                     │  Helm charts define
                     │  package structure
                     │
              ┌──────┴──────┐
              │    Helm     │
              │ (templating │
              │  + release  │
              │  management)│
              └─────────────┘
```

## Components

**Kubernetes** is the container orchestration platform. It schedules pods across worker nodes, manages networking (Services, Ingress), handles storage (PersistentVolumes), and maintains desired state through its control loop. The API server is the central interface; all other components interact through it.

**Helm** is the package manager. It templates Kubernetes manifests into reusable charts with configurable `values.yaml` files. Helm tracks releases (install, upgrade, rollback) and manages chart dependencies. Charts can come from public repositories (Artifact Hub) or private registries.

**ArgoCD** implements GitOps. It watches a Git repository for Kubernetes manifests or Helm charts, compares the desired state in Git against the live cluster state, and syncs differences. ArgoCD runs inside the cluster as a set of controllers and provides a web UI and CLI for managing applications.

**Container Registry** stores OCI container images. Kubernetes pulls images from the registry when scheduling pods. A private registry (Harbor, Docker Registry, or a cloud provider registry) gives you control over image distribution, vulnerability scanning, and access control.

**etcd** is the Kubernetes control plane's data store. It holds all cluster state: pod specs, secrets, config maps, RBAC rules, and custom resources. Kubernetes manages its own etcd in most setups (kubeadm, k3s embed it), but understanding etcd operations is critical for backup, recovery, and performance tuning.

## Prerequisites

- **Nodes**: 1 control plane + 2 workers minimum for production (3 control plane nodes for HA)
- **OS**: Debian 12+ / Ubuntu 22.04+ / RHEL 9+ with systemd
- **CPU/RAM**: Control plane nodes: 2+ vCPU, 4+ GB RAM. Worker nodes: sized to workload (2+ vCPU, 4+ GB RAM minimum)
- **Networking**: All nodes must reach each other. Pod network CIDR must not overlap with node/service CIDRs. DNS resolution required (internal and external).
- **Ports**: 6443 (API server), 2379-2380 (etcd), 10250 (kubelet), 10259 (scheduler), 10257 (controller-manager), 30000-32767 (NodePort range)
- **Container runtime**: containerd (default for k3s and kubeadm since K8s 1.24)
- **DNS**: Wildcard DNS or individual records for Ingress endpoints, ArgoCD UI, and registry hostname

## Quick Start

Minimal platform using k3s (lightweight Kubernetes), Helm, and ArgoCD. Production clusters should add node hardening, network policies, and proper TLS.

```bash
# --- 1. Install k3s on the first node (server) ---
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik   # we'll use our own ingress

# Grab the node token for joining workers
cat /var/lib/rancher/k3s/server/node-token

# Verify
kubectl get nodes
kubectl get pods -A

# --- 2. Join worker nodes ---
curl -sfL https://get.k3s.io | K3S_URL=https://server-ip:6443 \
    K3S_TOKEN=<node-token> sh -

# --- 3. Install Helm ---
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# --- 4. Install ArgoCD via Helm ---
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
    --namespace argocd \
    --set server.service.type=NodePort

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d; echo

# Access the ArgoCD UI (NodePort)
kubectl -n argocd get svc argocd-server \
    -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}'; echo
# Open https://server-ip:<nodeport> in browser

# --- 5. Install ArgoCD CLI ---
curl -sSL -o /usr/local/bin/argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Login
argocd login server-ip:<nodeport> --username admin --password <password> --insecure

# --- 6. Create your first ArgoCD application ---
argocd app create my-app \
    --repo https://github.com/your-org/k8s-manifests.git \
    --path apps/my-app \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace default \
    --sync-policy automated \
    --auto-prune \
    --self-heal

# Verify
argocd app list
argocd app get my-app
```

## Data Flow

### CI/CD Pipeline: Code to Running Pod

1. **Developer pushes code** to the application source repository
2. **CI pipeline builds** a container image and tags it (e.g., `registry.example.com/myapp:v1.2.3`)
3. **CI pushes the image** to the private container registry
4. **Developer or CI updates** the Kubernetes manifests or Helm chart values in the GitOps repository (changes the image tag)
5. **ArgoCD detects** the Git change (polling every 3 minutes by default, or via webhook for instant sync)
6. **ArgoCD renders** the manifests (Helm template, Kustomize, or plain YAML) and compares them against the live cluster state
7. **ArgoCD applies** the diff to the Kubernetes API server (`kubectl apply` equivalent)
8. **Kubernetes scheduler** assigns the new pods to worker nodes
9. **kubelet** on each node pulls the image from the container registry and starts the container
10. **Kubernetes** rolls out the new version (rolling update by default), shifting traffic once readiness probes pass

### Rollback

ArgoCD tracks sync history. Rolling back is a Git revert (preferred) or `argocd app rollback my-app <revision>`. Both trigger a new sync cycle that restores the previous state.

## Integration Points

### Helm and Kubernetes API

Helm communicates directly with the Kubernetes API server. It stores release state as Secrets in the release namespace (not in Tiller since Helm 3). When Helm renders a chart, it produces standard Kubernetes YAML and applies it via the API.

ArgoCD can deploy Helm charts natively. When an ArgoCD Application specifies a Helm source, ArgoCD runs `helm template` internally and manages the rendered manifests through its own sync engine. This means Helm releases managed by ArgoCD do NOT appear in `helm list` because ArgoCD bypasses Helm's release tracking.

### ArgoCD, Git, and Kubernetes

ArgoCD watches one or more Git repositories. Each ArgoCD Application maps a Git path (containing manifests, Helm charts, or Kustomize overlays) to a target cluster and namespace. ArgoCD's sync loop:

1. Polls Git (or receives webhook) for changes
2. Renders manifests from the source (Helm, Kustomize, or plain YAML)
3. Compares rendered manifests against live cluster state (three-way diff)
4. Applies or prunes resources to match the desired state

Auto-sync and self-heal (when enabled) ensure the cluster always converges to what Git declares. Manual changes made via `kubectl` are detected and reverted.

### Container Registry and Kubernetes

Kubernetes pulls images from the registry via the container runtime (containerd). For private registries, each namespace needs an `imagePullSecret` that contains registry credentials. Alternatively, configure the containerd `hosts.toml` on each node for cluster-wide registry access without per-namespace secrets.

### etcd and the API Server

The Kubernetes API server is the sole client of etcd. All cluster state (pods, services, secrets, config maps, RBAC bindings, CRDs) is stored in etcd. Operators never interact with etcd directly during normal operations; everything goes through `kubectl` or the API.

Direct etcd access is needed for disaster recovery (snapshot restore), performance diagnostics, and defragmentation.

## Day-2 Operations

### Kubernetes Upgrades

For k3s, upgrades are straightforward:

```bash
# On the server node
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.4+k3s1 sh -

# On worker nodes
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.4+k3s1 \
    K3S_URL=https://server-ip:6443 K3S_TOKEN=<token> sh -
```

For kubeadm clusters, follow the official upgrade sequence: control plane first, then workers, one node at a time. Drain each worker before upgrading (`kubectl drain <node> --ignore-daemonsets`).

### etcd Backup

etcd snapshots capture the full cluster state. Take regular snapshots; store them off-cluster.

```bash
# k3s embeds etcd — use k3s etcd-snapshot
k3s etcd-snapshot save --name manual-backup

# kubeadm / standalone etcd
ETCDCTL_API=3 etcdctl snapshot save /backups/etcd-$(date +%Y%m%d).db \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key

# Verify the snapshot
etcdctl snapshot status /backups/etcd-$(date +%Y%m%d).db -w table
```

### Monitoring

Deploy Prometheus + Grafana via Helm for cluster-wide monitoring.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    --set grafana.adminPassword=CHANGE_ME

# ArgoCD exposes Prometheus metrics on :8082/metrics
# Add a ServiceMonitor or scrape config for ArgoCD's metrics endpoint
```

### Scaling

```bash
# Horizontal Pod Autoscaler (requires metrics-server, included in k3s)
kubectl autoscale deployment my-app --cpu-percent=70 --min=2 --max=10

# Add a worker node
curl -sfL https://get.k3s.io | K3S_URL=https://server-ip:6443 \
    K3S_TOKEN=<token> sh -

# Verify node joined
kubectl get nodes
```

### ArgoCD Application Management

```bash
# List all apps
argocd app list

# Sync an app manually
argocd app sync my-app

# View sync status and health
argocd app get my-app

# View diff before syncing
argocd app diff my-app

# Rollback to a previous revision
argocd app rollback my-app 3

# Delete an app (does NOT delete the Kubernetes resources by default)
argocd app delete my-app
# To also delete resources: argocd app delete my-app --cascade
```

## See Also

- **kubernetes** -- Kubernetes concepts, kubectl reference, workloads, networking, storage
- **helm** -- Helm chart development, templating, repository management
- **argocd** -- ArgoCD configuration, ApplicationSets, RBAC, SSO, notifications
- **container-registry** -- Private registry setup (Harbor, Docker Registry)
- **etcd** -- etcd cluster operations, backup, restore, maintenance
- **docker** -- Container image building, Dockerfile best practices

## References

See `references/` for:
- `common-patterns.md` -- k3s cluster setup, Helm chart deployment, ArgoCD app-of-apps pattern, private registry with imagePullSecret, etcd backup cronjob
- `docs.md` -- Links to official documentation for all components
