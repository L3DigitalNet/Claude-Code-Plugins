---
name: trivy
description: >
  Trivy container and filesystem vulnerability scanner: image scanning, filesystem
  scanning, SBOM generation, configuration scanning for Dockerfile/Kubernetes/Terraform,
  secret detection, license scanning, CI integration, and severity filtering.
  MUST consult when installing, configuring, or troubleshooting trivy.
triggerPhrases:
  - "trivy"
  - "Trivy"
  - "trivy image"
  - "trivy scan"
  - "trivy fs"
  - "trivy config"
  - "vulnerability scan"
  - "container scan"
  - "SBOM"
  - "sbom"
  - "trivy kubernetes"
  - "trivy misconfig"
  - "trivy secret"
  - "image vulnerability"
  - "security scan"
globs:
  - "**/trivy.yaml"
  - "**/trivy.yml"
  - "**/.trivyignore"
  - "**/.trivyignore.yaml"
last_verified: "2026-03"
---

## Identity

| Field | Value |
|-------|-------|
| Binary | `trivy` |
| Config | `trivy.yaml` (in project root or `--config` flag) |
| Cache | `~/.cache/trivy/` (DB, Java index, checks bundle) |
| Ignore file | `.trivyignore` (CVE IDs or rule IDs to skip, one per line) |
| Install | `apt install trivy` / `brew install trivy` / `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \| sh` / Docker: `aquasec/trivy` |
| Version check | `trivy --version` |

## Quick Start

```bash
# Install
sudo apt install trivy

# Scan a container image for vulnerabilities
trivy image nginx:latest

# Scan only HIGH and CRITICAL, ignore unfixed
trivy image --severity HIGH,CRITICAL --ignore-unfixed alpine:3.20

# Scan local filesystem for vulnerabilities and secrets
trivy fs --scanners vuln,secret .

# Scan IaC configs (Dockerfile, Kubernetes, Terraform)
trivy config .

# Generate SBOM in CycloneDX format
trivy image --format cyclonedx --output sbom.cdx.json nginx:latest
```

## Key Operations

| Task | Command |
|------|---------|
| Scan container image | `trivy image <image>` |
| Scan image (tar archive) | `trivy image --input <file.tar>` |
| Scan filesystem | `trivy fs <path>` |
| Scan Git repository | `trivy repo <url>` |
| Scan IaC configuration | `trivy config <path>` |
| Scan Kubernetes cluster | `trivy kubernetes --report summary` |
| Scan SBOM file | `trivy sbom <sbom-file>` |
| Scan rootfs | `trivy rootfs <path>` |
| Filter by severity | `--severity HIGH,CRITICAL` |
| Show only fixed vulns | `--ignore-unfixed` |
| Set exit code on findings | `--exit-code 1` |
| Output as JSON | `--format json --output result.json` |
| Output as SARIF | `--format sarif --output result.sarif` |
| Output as table | `--format table` (default) |
| Generate CycloneDX SBOM | `--format cyclonedx --output sbom.cdx.json` |
| Generate SPDX SBOM | `--format spdx-json --output sbom.spdx.json` |
| Select scanners | `--scanners vuln,misconfig,secret,license` |
| Scan Terraform only | `trivy config --misconfig-scanners terraform <path>` |
| Scan Dockerfiles only | `trivy config --misconfig-scanners dockerfile <path>` |
| Custom checks | `trivy config --config-check <policy-dir> <path>` |
| Skip directories | `--skip-dirs node_modules,vendor,.git` |
| Skip files | `--skip-files package-lock.json` |
| Use custom DB mirror | `--db-repository <oci-url>` |
| Clear cache | `trivy clean --all` |
| Download/update DB only | `trivy image --download-db-only` |
| Set timeout | `--timeout 10m` (default 5m) |
| Specify platform | `--platform linux/amd64` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `FATAL failed to initialize DB` | DB not downloaded or cache corrupt | `trivy clean --all && trivy image --download-db-only`; check internet access |
| DB download timeout | Slow connection or OCI registry unreachable | `--timeout 15m`; use `--db-repository` to point to a mirror |
| Scan finds zero results | Wrong scanner type selected | Verify `--scanners` flag; `vuln` for vulnerabilities, `misconfig` for IaC, `secret` for secrets |
| False positive vulnerability | CVE doesn't apply to actual usage | Add CVE ID to `.trivyignore`; or use `--ignore-unfixed` to skip unpatched vulns |
| `trivy config` shows nothing | No supported IaC files in path | Ensure path contains Dockerfile, Kubernetes YAML, Terraform .tf, or CloudFormation templates |
| Exit code 0 despite findings | `--exit-code` not set | Add `--exit-code 1` for CI pipelines to fail on findings |
| Image not found | Docker daemon not running or image not pulled | Use `--image-src remote` to pull directly; or `docker pull <image>` first |
| `--platform` required | Multi-platform image, Trivy picks wrong one | Specify `--platform linux/amd64` (or your target arch) explicitly |
| Slow scans | Large image or full DB download each run | Use CI caching for `~/.cache/trivy/`; use `--skip-dirs` to exclude irrelevant paths |

## Pain Points

- **DB freshness matters.** Trivy downloads a vulnerability database on first run and caches it. Stale DBs miss recent CVEs. In CI, either cache the DB directory with a TTL or run `trivy image --download-db-only` as a separate step. The DB is updated every 6 hours upstream.
- **Scanner selection is not obvious.** `trivy image` defaults to `vuln,secret` scanners. `trivy fs` defaults to `vuln,secret`. `trivy config` runs `misconfig` only. If you want everything (vulns + misconfigs + secrets + licenses), pass `--scanners vuln,misconfig,secret,license` explicitly.
- **Severity levels are cumulative.** `--severity HIGH,CRITICAL` shows both HIGH and CRITICAL. The default includes all levels (UNKNOWN through CRITICAL). For CI gates, combine `--severity HIGH,CRITICAL` with `--exit-code 1` to fail only on serious findings.
- **SBOM generation and scanning are separate.** `trivy image --format cyclonedx` generates an SBOM. `trivy sbom <file>` scans an existing SBOM for vulnerabilities. You can generate once and scan repeatedly as the DB updates.
- **`.trivyignore` accepts CVE IDs and check IDs.** One entry per line. For time-boxed ignores, use `.trivyignore.yaml` with expiration dates: `- id: CVE-2024-1234 expired_at: 2026-06-01`. This prevents permanent ignore rules from hiding real issues.
- **Config scanning detects real misconfigs.** `trivy config` catches things like running as root in Dockerfiles, missing resource limits in Kubernetes manifests, and overly permissive security groups in Terraform. The checks are maintained upstream and updated with the checks bundle.

## See Also

- **docker** -- Container runtime; Trivy's primary scanning target for container images
- **kubernetes** -- Cluster scanning target; `trivy kubernetes` scans running workloads for vulnerabilities and misconfigs

## References

See `references/` for:
- `cheatsheet.md` -- quick reference for all Trivy commands and common flag combinations
- `docs.md` -- official documentation links
