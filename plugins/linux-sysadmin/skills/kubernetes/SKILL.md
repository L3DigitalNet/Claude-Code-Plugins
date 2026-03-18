---
name: kubernetes
description: >
  Kubernetes container orchestration: kubectl operations, cluster management,
  workload deployment, services, networking, storage, RBAC, troubleshooting,
  and common administrative tasks. Covers kubeadm, k3s, and managed cluster basics.
  MUST consult when installing, configuring, or troubleshooting kubernetes.
triggerPhrases:
  - kubernetes
  - kubectl
  - k8s
  - pod
  - deployment
  - service
  - namespace
  - ingress
  - configmap
  - secret
  - persistent volume
  - PVC
  - node
  - cluster
  - kubeadm
  - k3s
  - minikube
  - kube-system
  - kubelet
  - kube-proxy
  - container orchestration
  - rolling update
  - rollback
  - horizontal pod autoscaler
  - HPA
  - DaemonSet
  - StatefulSet
last_verified: "2026-03"
globs:
  - "**/*.yaml"
  - "**/*.yml"
  - "**/kubeconfig"
  - "**/.kube/config"
---

## Identity

### Control Plane Components
- **kube-apiserver**: Exposes the Kubernetes HTTP API. Front end for the control plane.
- **etcd**: Consistent, highly-available key-value store backing all cluster data.
- **kube-scheduler**: Assigns unbound Pods to suitable nodes based on resource requirements, affinity, taints.
- **kube-controller-manager**: Runs controllers that implement Kubernetes API behavior (Deployment, ReplicaSet, Node, Job controllers, etc.).
- **cloud-controller-manager** (optional): Integrates with underlying cloud provider APIs.

### Node Components
- **kubelet**: Agent on each node; ensures containers described in PodSpecs are running and healthy.
- **kube-proxy** (optional): Network proxy on each node; maintains iptables/IPVS rules for Service routing.
- **Container runtime**: containerd (default since v1.24), CRI-O, or other CRI-compliant runtime. Docker Engine (dockershim) was removed in v1.24.

### Config Paths
- **Kubeconfig (user)**: `~/.kube/config` (override with `KUBECONFIG` env var or `--kubeconfig` flag)
- **Kubeconfig (kubelet)**: `/etc/kubernetes/kubelet.conf`
- **Kubelet config**: `/var/lib/kubelet/config.yaml`
- **Static pod manifests**: `/etc/kubernetes/manifests/` (kubeadm-managed clusters)
- **Kubeadm flags**: `/var/lib/kubelet/kubeadm-flags.env`
- **K3s config**: `/etc/rancher/k3s/config.yaml` (drop-ins: `/etc/rancher/k3s/config.yaml.d/*.yaml`)
- **K3s kubeconfig**: `/etc/rancher/k3s/k3s.yaml`

### Default Ports

| Component | Port | Protocol | Notes |
|-----------|------|----------|-------|
| kube-apiserver | 6443 | TCP | Commonly placed behind LB on 443 |
| etcd | 2379-2380 | TCP | 2379 client, 2380 peer |
| kubelet | 10250 | TCP | Kubelet API on every node |
| kube-scheduler | 10259 | TCP | Secure port (self only) |
| kube-controller-manager | 10257 | TCP | Secure port (self only) |
| kube-proxy | 10256 | TCP | Health check endpoint |
| NodePort range | 30000-32767 | TCP/UDP | Default; configurable via `--service-node-port-range` |

## Quick Start

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install kubectl /usr/local/bin/

# Check client and server versions
kubectl version

# List all nodes in the cluster
kubectl get nodes
```

## Key Operations

| Task | Command |
|------|---------|
| Cluster info | `kubectl cluster-info` / `kubectl version` |
| List resources | `kubectl get <type>` (add `-o wide`, `-o yaml`, `-o json`, `--all-namespaces` / `-A`) |
| Inspect resource | `kubectl describe <type> <name>` |
| Create from manifest | `kubectl apply -f <file.yaml>` (declarative, idempotent) or `kubectl create -f <file.yaml>` (imperative, errors if exists) |
| Delete | `kubectl delete <type> <name>` or `kubectl delete -f <file.yaml>` |
| Logs | `kubectl logs <pod>` / `kubectl logs <pod> -c <container>` / `kubectl logs <pod> --previous` / `kubectl logs -f <pod>` (follow) |
| Exec into pod | `kubectl exec -it <pod> -- /bin/sh` (or `bash`) |
| Port-forward | `kubectl port-forward <pod> <local>:<remote>` (also works with `svc/<name>`) |
| Scale | `kubectl scale deployment <name> --replicas=<n>` |
| Rollout status | `kubectl rollout status deployment/<name>` |
| Rollout history | `kubectl rollout history deployment/<name>` |
| Rollout undo | `kubectl rollout undo deployment/<name>` |
| Set image | `kubectl set image deployment/<name> <container>=<image>:<tag>` |
| Cordon node | `kubectl cordon <node>` |
| Uncordon node | `kubectl uncordon <node>` |
| Drain node | `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` |
| Debug pod | `kubectl debug pod/<name> -it --image=busybox:1.36` |
| Node/pod metrics | `kubectl top nodes` / `kubectl top pods` (requires metrics-server) |
| Events | `kubectl events` or `kubectl get events --sort-by=.metadata.creationTimestamp` |
| Explain schema | `kubectl explain <type>` / `kubectl explain <type>.spec --recursive` |
| Switch context | `kubectl config use-context <name>` / `kubectl config get-contexts` |
| Set namespace | `kubectl config set-context --current --namespace=<ns>` |

## Workload Types

| Type | When to use | Key traits |
|------|-------------|------------|
| **Pod** | Almost never directly; foundation for everything else | Smallest deployable unit. Ephemeral. No self-healing. |
| **Deployment** | Stateless apps (web servers, APIs) | Manages ReplicaSets. Rolling updates, rollbacks. Pods are interchangeable. |
| **ReplicaSet** | Rarely managed directly; Deployment creates them | Ensures N identical pods are running. |
| **StatefulSet** | Stateful apps (databases, caches, message queues) | Stable network identity, ordered deployment/scaling, persistent storage per pod. |
| **DaemonSet** | One pod per node (log collectors, monitoring agents, CNI plugins) | Automatically schedules on new nodes. Ignores normal scheduling constraints. |
| **Job** | One-time batch tasks (migrations, data processing) | Runs to completion, then stops. Configurable parallelism and retry. |
| **CronJob** | Scheduled recurring tasks (backups, reports, cleanup) | Creates Jobs on a cron schedule. Supports concurrency policies. |

## Networking

### Service Types

| Type | Scope | Use case |
|------|-------|----------|
| **ClusterIP** (default) | Cluster-internal only | Service-to-service communication |
| **NodePort** | External via `<NodeIP>:30000-32767` | Dev/test; simple external access |
| **LoadBalancer** | External via cloud LB | Production external access (requires cloud provider or MetalLB) |
| **ExternalName** | DNS CNAME alias | Proxy to an external service by DNS name |

### Service DNS
Services are reachable at `<service>.<namespace>.svc.cluster.local`. Within the same namespace, just `<service>` works.

### Ingress
Manages external HTTP/HTTPS access with host/path-based routing. Requires an Ingress controller (nginx-ingress, Traefik, etc.). The Kubernetes project now recommends Gateway API as the successor to Ingress; the Ingress API is frozen but stable.

### NetworkPolicy
Namespace-scoped firewall rules controlling pod-to-pod and pod-to-external traffic. Requires a CNI plugin that supports NetworkPolicy (Calico, Cilium, Weave Net). Without a supporting CNI, NetworkPolicy resources are silently ignored.

## Storage

### Core Concepts

| Resource | Scope | Purpose |
|----------|-------|---------|
| **PersistentVolume (PV)** | Cluster-wide | Represents a piece of storage provisioned by an admin or dynamically |
| **PersistentVolumeClaim (PVC)** | Namespace-scoped | User's request for storage; binds 1:1 to a PV |
| **StorageClass** | Cluster-wide | Defines provisioner and parameters for dynamic PV creation |

### Access Modes
- **RWO** (ReadWriteOnce): Single node read-write
- **ROX** (ReadOnlyMany): Many nodes read-only
- **RWX** (ReadWriteMany): Many nodes read-write
- **RWOP** (ReadWriteOncePod): Single pod read-write (v1.29+ stable)

### Reclaim Policies
- **Retain**: PV persists after PVC deletion; manual cleanup required
- **Delete**: PV and underlying storage deleted automatically (default for dynamic provisioning)
- **Recycle**: Deprecated; use dynamic provisioning instead

## Expected Ports
See the Default Ports table in Identity. For quick firewall rules:
- Control plane: 6443, 2379-2380, 10250, 10257, 10259
- Workers: 10250, 10256, 30000-32767

## Health Checks
1. `kubectl cluster-info` — API server and CoreDNS reachable
2. `kubectl get nodes` — all nodes `Ready`
3. `kubectl get componentstatuses` — (deprecated but still works) scheduler, controller-manager, etcd health
4. `kubectl get pods -n kube-system` — control plane pods running
5. `kubectl top nodes` — resource metrics flowing (requires metrics-server)
6. `kubectl run test --image=busybox:1.36 --rm -it -- nslookup kubernetes` — DNS resolution inside cluster

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `CrashLoopBackOff` | App crashes on start; bad config, missing deps, failed probes | `kubectl logs <pod> --previous`; check env vars, configmaps, secrets, probe config |
| `ImagePullBackOff` | Image doesn't exist, wrong tag, or private registry without `imagePullSecrets` | `kubectl describe pod <pod>` Events section; verify image name, registry auth |
| Pod stuck `Pending` | No node with sufficient CPU/memory, unbound PVC, unsatisfied affinity/taint | `kubectl describe pod <pod>` for scheduling errors; check node resources with `kubectl describe node` |
| `OOMKilled` (exit 137) | Container exceeded memory limit | Increase `resources.limits.memory` or fix the memory leak; check `kubectl describe pod` |
| Node `NotReady` | kubelet down, network partition, disk pressure, memory pressure | `kubectl describe node <node>` Conditions; check `journalctl -u kubelet` on the node |
| `Forbidden` / RBAC denied | ServiceAccount or user lacks permissions | `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa>` |
| `CreateContainerConfigError` | Referenced ConfigMap or Secret doesn't exist | `kubectl describe pod <pod>` Events; verify the CM/Secret exists in the same namespace |
| Readiness probe failing | App not ready, wrong port/path, probe too aggressive | Check probe config; increase `initialDelaySeconds` / `failureThreshold`; test the endpoint manually |
| Service has no endpoints | Selector doesn't match any pod labels, or pods aren't Ready | `kubectl get endpoints <svc>` (empty = no match); compare `svc` selector with pod labels |

## Pain Points
- **Context switching**: `kubectl` operates on whichever context is active. Accidentally running commands against production is easy. Use `kubectx`/`kubens` or shell prompts showing current context. Set `KUBECONFIG` per terminal.
- **Namespace gotchas**: Resources default to `default` namespace. Forgetting `-n <ns>` is the #1 "I can't see my pods" issue. Set a default namespace: `kubectl config set-context --current --namespace=<ns>`.
- **Resource limits**: Pods without `requests` and `limits` get best-effort QoS and are killed first under pressure. Always set them; HPA requires `requests` to calculate utilization.
- **Probe configuration**: Liveness probes that are too aggressive cause unnecessary restarts. Readiness probes that never pass make the pod perpetually unavailable. Start with generous timings and tighten.
- **Secret management**: Secrets are base64-encoded, not encrypted. Enable encryption at rest for etcd. Consider external secret operators (External Secrets Operator, Sealed Secrets, Vault) for production.
- **YAML sprawl**: Manifest files multiply fast. Use Kustomize (built into kubectl) or Helm to manage environment-specific overrides.
- **Rolling update gotchas**: If the new image is broken, the rollout stalls with mixed old/new pods. Set `maxUnavailable` and `maxSurge` deliberately. Use `kubectl rollout undo` to revert.
- **Ephemeral containers**: `kubectl debug` requires ephemeral containers support (stable since v1.25). Distroless images have no shell; debug containers are the primary troubleshooting path.

## See Also

- `helm` — Kubernetes package manager for chart-based deployments
- `docker` — Container image building and local container runtime
- `docker-compose` — Multi-container local development environments
- `traefik` — Ingress controller and reverse proxy for Kubernetes
- `container-registry` — Container image storage and distribution
- **argocd** — GitOps continuous delivery; declarative app deployment and sync
- **vault** — secrets management for Kubernetes workloads via CSI driver or sidecar
- **trivy** — vulnerability scanning for container images and Kubernetes manifests
- **etcd** — distributed key-value store that backs the Kubernetes API server

## References
See `references/` for:
- `cheatsheet.md` — essential kubectl commands organized by category
- `common-patterns.md` — practical YAML examples for common workload patterns
- `docs.md` — official documentation links
