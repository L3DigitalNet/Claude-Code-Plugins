---
name: helm
description: >
  Helm Kubernetes package manager: chart installation, upgrades, rollbacks,
  repository management, values overrides, chart development, templating,
  and release management. The standard way to package and deploy Kubernetes applications.
  MUST consult when installing, configuring, or troubleshooting helm.
triggerPhrases:
  - helm
  - helm chart
  - helm install
  - helm upgrade
  - helm repo
  - helm values
  - helm template
  - helm rollback
  - helm release
  - kubernetes package
  - chart repository
  - helm dependency
  - helm plugin
  - Artifact Hub
  - OCI registry helm
last_verified: "2026-03"
globs:
  - "**/Chart.yaml"
  - "**/Chart.lock"
  - "**/values.yaml"
  - "**/values*.yaml"
  - "**/templates/**/*.yaml"
  - "**/templates/**/*.tpl"
  - "**/.helmignore"
---

## Identity

| Field | Value |
|-------|-------|
| Binary | `helm` (typically `/usr/local/bin/helm`) |
| Config | `~/.config/helm/` (repos, registry auth, plugins) |
| Cache | `~/.cache/helm/` (chart archives, repository indexes) |
| Data | `~/.local/share/helm/` (plugins, starters) |
| Release storage | Kubernetes Secrets in the release namespace (default driver) |
| Key env vars | `HELM_CACHE_HOME`, `HELM_CONFIG_HOME`, `HELM_DATA_HOME`, `HELM_NAMESPACE`, `HELM_DRIVER` (secret\|configmap\|memory\|sql), `HELM_MAX_HISTORY`, `KUBECONFIG` |
| Install | `curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 \| bash` or `brew install helm` / `snap install helm --classic` |
| Version check | `helm version`; current stable is v4.1.x (v3.20.x still maintained with security fixes until Nov 2026) |

## Quick Start

```bash
# Install Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

# Add the Bitnami chart repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Search for nginx charts
helm search repo nginx
```

## Key Operations

| Task | Command |
|------|---------|
| Install a chart | `helm install <release> <chart> [-f values.yaml] [--set key=val] [--namespace ns] [--create-namespace]` |
| Upgrade a release | `helm upgrade <release> <chart> [-f values.yaml] [--rollback-on-failure] [--wait] [--timeout 5m]` |
| Rollback | `helm rollback <release> <revision>` |
| Uninstall | `helm uninstall <release> [--namespace ns]` |
| List releases | `helm list [-A]` (all namespaces with `-A`) |
| Release status | `helm status <release>` |
| Release history | `helm history <release>` |
| Get deployed values | `helm get values <release>` / `helm get manifest <release>` |
| Add repo | `helm repo add <name> <url>` |
| Update repos | `helm repo update` |
| Search local repos | `helm search repo <keyword>` |
| Search Artifact Hub | `helm search hub <keyword>` |
| Show chart values | `helm show values <chart>` |
| Render templates locally | `helm template <release> <chart> [-f values.yaml]` |
| Lint chart | `helm lint <chart-path>` |
| Dry run | `helm install <release> <chart> --dry-run --debug` |

## Chart Structure
```
mychart/
├── Chart.yaml          # Required: name, version, apiVersion (v2)
├── Chart.lock          # Pinned dependency versions (auto-generated)
├── values.yaml         # Default configuration values
├── values.schema.json  # Optional JSON Schema for values validation
├── charts/             # Dependency charts (populated by helm dependency update)
├── crds/               # Custom Resource Definitions (applied before templates)
├── templates/          # Kubernetes manifest templates
│   ├── _helpers.tpl    # Named template definitions (partials)
│   ├── NOTES.txt       # Post-install usage notes (rendered, shown to user)
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── .helmignore         # Files to exclude from chart package
```

## Templating
Helm uses Go templates (`{{ }}` delimiters) with Sprig functions.

**Built-in objects:**
- `.Values` — merged values from `values.yaml` + overrides
- `.Release.Name`, `.Release.Namespace`, `.Release.Revision`, `.Release.IsUpgrade`, `.Release.IsInstall`
- `.Chart.Name`, `.Chart.Version`, `.Chart.AppVersion`
- `.Capabilities.KubeVersion`, `.Capabilities.APIVersions.Has "batch/v1"`
- `.Template.Name`, `.Template.BasePath`
- `.Files.Get "config.ini"`, `.Files.Glob "files/*"`, `.Files.AsSecrets`, `.Files.AsConfig`

**Essential functions:**
- `default "fallback" .Values.key` — provide default when value is empty
- `required "msg" .Values.key` — fail rendering if value is missing
- `toYaml .Values.resources | nindent 2` — convert to YAML with indentation
- `include "mychart.labels" . | nindent 4` — render named template (prefer over `template` for pipeline support)
- `tpl .Values.dynamicTemplate .` — evaluate a string as a template
- `quote`, `upper`, `lower`, `trim`, `replace`, `contains`, `hasKey`, `empty`, `coalesce`, `ternary`, `lookup`

**Named templates** (`_helpers.tpl`):
```
{{- define "mychart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
```
Use with: `{{ include "mychart.fullname" . }}`

Template names are global across all subcharts; prefix with the chart name to avoid collisions.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Release stuck in `pending-install` / `pending-upgrade` | Previous operation timed out or crashed | `helm history <release>`; if stuck, `helm rollback` to last good revision or `helm uninstall` and reinstall |
| `UPGRADE FAILED: has no deployed releases` | First install failed, leaving a failed state | `helm uninstall <release>` then `helm install` again |
| `rendered manifests contain a resource that already exists` | Resource created outside Helm or by another release | Adopt with `kubectl annotate` meta.helm.sh/release-name and meta.helm.sh/release-namespace, then set label app.kubernetes.io/managed-by=Helm |
| Values override not taking effect | Precedence: `--set` > `-f custom.yaml` > `values.yaml` (rightmost `--set`/`-f` wins) | Use `helm get values <release>` to verify; check nesting (YAML keys are case-sensitive) |
| `Error: chart requires kubeVersion >=1.25` | Cluster version doesn't match Chart.yaml `kubeVersion` | Upgrade cluster or adjust `kubeVersion` constraint |
| OCI registry auth failure | Missing `helm registry login` or expired token | `helm registry login <registry>` before push/pull |
| `helm dependency update` fails | Repo not added or chart version not found | Verify repo with `helm repo list`; check version exists with `helm search repo <dep> --versions` |

## Pain Points
- **Helm 3 vs 4**: Helm 4 (current) uses server-side apply by default for new installs, kstatus for readiness checks, and optional WASM plugins. Helm 3 charts (apiVersion v2) remain fully compatible. `--atomic` was renamed to `--rollback-on-failure`. Helm 3 receives security fixes until Nov 2026.
- **Helm 2 (EOL)**: Used server-side Tiller component; completely removed in Helm 3. If you encounter Helm 2 references, they are obsolete.
- **Atomic installs**: `--rollback-on-failure --wait` auto-rolls back on failure and waits for readiness. Without it, a failed upgrade leaves the release in `failed` state requiring manual rollback.
- **Release naming**: Release names are scoped to a namespace. Same chart can have different releases in different namespaces.
- **Namespace scoping**: `helm list` shows only the current namespace; use `-A` for all. Resources are created in `--namespace` (or current context namespace).
- **Hook resources are untracked**: Helm hooks (pre-install, post-upgrade, etc.) create resources not managed by the release. They need `hook-delete-policy` annotations or manual cleanup.
- **Three-way merge gotchas (v3)**: Helm 3 uses client-side 3-way merge, which can silently overwrite manual changes. Helm 4's server-side apply detects conflicts explicitly.
- **Values type coercion**: Bare `true`/`false` and numbers in values.yaml are parsed as booleans/ints. Quote them if you need strings: `"true"`, `"8080"`.

## See Also

- `kubernetes` — Kubernetes cluster management and kubectl operations
- `docker` — Container image building and runtime
- `container-registry` — OCI registry management for chart and image storage
- **argocd** — GitOps delivery that deploys Helm charts declaratively

## References
See `references/` for:
- `docs.md` — official documentation links
- `cheatsheet.md` — essential Helm commands quick reference
- `chart-template.yaml` — annotated minimal Chart.yaml
- `common-patterns.md` — practical Helm usage patterns
