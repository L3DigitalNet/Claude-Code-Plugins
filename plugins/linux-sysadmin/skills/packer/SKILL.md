---
name: packer
description: >
  HashiCorp Packer machine image automation: HCL2 templates, sources (builders),
  provisioners, post-processors, plugin management, and the init/validate/build
  workflow for QEMU/KVM, Docker, and cloud images (AWS AMI).
  MUST consult when installing, configuring, or troubleshooting packer.
triggerPhrases:
  - packer
  - packer build
  - packer init
  - packer validate
  - machine image
  - golden image
  - image builder
  - packer template
  - packer plugin
  - .pkr.hcl
  - amazon-ebs
  - packer qemu
  - packer docker
  - packer provisioner
  - packer post-processor
  - packer variable
  - PKR_VAR
last_verified: "2026-03"
globs:
  - "**/*.pkr.hcl"
  - "**/*.pkrvars.hcl"
  - "**/*.auto.pkrvars.hcl"
---

## Identity

| Field | Value |
|-------|-------|
| Binary | `packer` (HashiCorp, BSL 1.1 license since v1.9.3, Aug 2023) |
| Current version | 1.15.0 (Feb 2026) |
| Config dir | `$HOME/.config/packer/` (Linux), `%APPDATA%\packer.d\` (Windows) |
| Plugin dir | `$HOME/.config/packer/plugins/` (override: `PACKER_PLUGIN_PATH`) |
| Cache dir | `./packer_cache/` in working directory (override: `PACKER_CACHE_DIR`) |
| Template files | `*.pkr.hcl` (HCL2 format), `*.pkr.json` (JSON variant of HCL2) |
| Variable files | `*.pkrvars.hcl`, `*.auto.pkrvars.hcl` (auto-loaded) |
| Key env vars | `PKR_VAR_<name>` (input variables), `PACKER_LOG` (enable logging, any non-empty/non-zero value), `PACKER_LOG_PATH`, `PACKER_CACHE_DIR`, `PACKER_CONFIG_DIR`, `PACKER_PLUGIN_PATH`, `PACKER_NO_COLOR`, `PACKER_GITHUB_API_TOKEN` (rate limits for `packer init`), `CHECKPOINT_DISABLE=1` |

## Quick Start

```bash
# Install Packer (Debian/Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

# Minimal HCL2 template (docker.pkr.hcl)
cat <<'HCL'
packer {
  required_plugins {
    docker = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "ubuntu" {
  image  = "ubuntu:24.04"
  commit = true
}

build {
  sources = ["source.docker.ubuntu"]

  provisioner "shell" {
    inline = ["apt-get update && apt-get install -y curl"]
  }
}
HCL

# Standard workflow
packer init .          # download plugins declared in required_plugins
packer validate .      # check syntax and configuration
packer build .         # execute the build
```

## Key Operations

| Task | Command |
|------|---------|
| Init | `packer init .` -- download plugins from `required_plugins`. `-upgrade` to update to latest matching version. |
| Validate | `packer validate .` -- syntax + config check (no builds). `-syntax-only` for parse-only check. |
| Build | `packer build .` -- run all builds in template. `-only='source.qemu.myvm'` to target one source. `-on-error=ask\|abort\|cleanup\|run-cleanup-provisioner`. `-parallel-builds=1` to serialize. |
| Format | `packer fmt .` -- rewrite `.pkr.hcl` to canonical style. `-check` for CI (exit 1 if unformatted). `-diff` to show changes. |
| Inspect | `packer inspect .` -- list sources, variables, and their defaults. |
| Console | `packer console .` -- interactive expression evaluator. |
| Plugins install | `packer plugins install github.com/hashicorp/qemu` -- manually install a plugin. |
| Plugins installed | `packer plugins installed` -- list installed plugins and versions. |
| Plugins remove | `packer plugins remove github.com/hashicorp/qemu` -- uninstall a plugin. |
| HCL2 upgrade | `packer hcl2_upgrade template.json` -- convert legacy JSON to HCL2. |
| Debug build | `packer build -debug .` -- step-by-step build (pauses between steps, disables parallelism). |
| Build with vars | `packer build -var 'ami_name=my-image' -var-file=prod.pkrvars.hcl .` |

## Build Workflow

1. **Write** -- define sources, build blocks, provisioners, and post-processors in `*.pkr.hcl` files
2. **`packer init`** -- download/install required plugins from the registry
3. **`packer validate`** -- verify syntax and configuration correctness
4. **`packer build`** -- Packer launches the source (VM, container, cloud instance), runs provisioners in order, then executes post-processors on the resulting artifact

Builds run in parallel by default when multiple sources are defined. Use `-parallel-builds=N` to limit concurrency.

### Template Structure

```
project/
  main.pkr.hcl           # packer{}, source{}, build{} blocks
  variables.pkr.hcl      # variable{} declarations
  locals.pkr.hcl         # locals{} computed values
  prod.pkrvars.hcl       # variable values for production
  dev.auto.pkrvars.hcl   # auto-loaded variable values for dev
```

All `*.pkr.hcl` files in a directory are merged into a single configuration. Ordering of root-level blocks does not matter; ordering of provisioners and post-processors within a `build` block does.

### HCL2 Block Types

**`packer {}`** -- Packer version constraints and `required_plugins` declarations. Only constants allowed inside (no variable references).

**`source "<type>" "<name>" {}`** -- Defines a builder configuration (the machine to launch). Referenced by builds via `"source.<type>.<name>"`.

**`build {}`** -- Ties sources to provisioners and post-processors. Can reference multiple sources: `sources = ["source.docker.ubuntu", "source.qemu.vm"]`.

**`variable "<name>" {}`** -- Input variable with `type`, `default`, `description`, `sensitive`, and `validation` blocks. Set via CLI (`-var`), files (`-var-file`), env (`PKR_VAR_<name>`), or auto-loaded `*.auto.pkrvars.hcl`.

**`locals {}`** -- Computed values from expressions. Cannot be overridden externally.

**`data "<type>" "<name>" {}`** -- Read-only queries (e.g., look up an AMI ID). Plugin-provided; referenced as `data.<type>.<name>.<attribute>`.

### Contextual Variables

Available inside `build` blocks for provisioners and post-processors:

| Variable | Value |
|----------|-------|
| `build.name` | Name of the current build block |
| `build.ID` | VM/instance identifier (instance ID, VM name, etc.) |
| `source.name` | Name label of the source block |
| `source.type` | Type of the source (e.g., `amazon-ebs`, `qemu`) |
| `build.Host`, `build.Port`, `build.User`, `build.Password` | Connection details |
| `build.PackerRunUUID` | Unique identifier for the build run |
| `build.PackerHTTPAddr` | Address of the built-in HTTP server |
| `build.SSHPublicKey`, `build.SSHPrivateKey` | SSH key pair (SSH communicator) |
| `packer.version` | Current Packer version string |

## Sources (Builders)

Sources define the platform where the machine image is created. Since Packer 1.14.0, all official plugins are external and installed via `packer init`.

### QEMU/KVM

```hcl
packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "debian" {
  iso_url          = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso"
  iso_checksum     = "sha256:abcdef1234567890..."
  output_directory = "output-debian"
  format           = "qcow2"           # qcow2 (default) or raw
  accelerator      = "kvm"             # kvm, tcg, hvf, xen, none
  disk_size        = "20G"
  headless         = true
  http_directory   = "http"            # serve preseed/kickstart files
  boot_command     = ["<esc><wait>", "auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"]
  ssh_username     = "root"
  ssh_password     = "packer"
  ssh_timeout      = "30m"
  shutdown_command  = "shutdown -P now"
}
```

Output: QEMU-compatible disk image (qcow2/raw) in `output_directory`. Use with libvirt, Proxmox, or direct QEMU.

### Docker

```hcl
packer {
  required_plugins {
    docker = {
      version = "~> 1"
      source  = "github.com/hashicorp/docker"
    }
  }
}

# Commit mode: produces a Docker image in the local daemon
source "docker" "app" {
  image  = "ubuntu:24.04"
  commit = true
  changes = [
    "EXPOSE 8080",
    "CMD [\"/usr/bin/app\"]",
    "WORKDIR /opt/app",
  ]
}

# Export mode: produces a tar archive
source "docker" "app_tar" {
  image       = "ubuntu:24.04"
  export_path = "image.tar"
}
```

Commit vs export: `commit = true` saves the container as an image in the local Docker daemon. `export_path` writes a filesystem tar (requires `docker-import` post-processor to re-import). Use `docker-tag` and `docker-push` post-processors to tag and push to a registry.

### Amazon EBS (AWS AMI)

```hcl
packer {
  required_plugins {
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "my-app-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "us-east-1"
  ssh_username  = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]   # Canonical
    most_recent = true
  }

  tags = {
    Name    = "my-app"
    Builder = "packer"
  }
}
```

Authentication: uses standard AWS credential chain (env vars `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, shared credentials file, instance profile, or SSO).

## Provisioners

Provisioners run inside the machine after it boots. They execute in declaration order within a `build` block.

### Shell

```hcl
provisioner "shell" {
  inline = [
    "sudo apt-get update",
    "sudo apt-get install -y nginx",
  ]
}

provisioner "shell" {
  script           = "scripts/setup.sh"
  environment_vars = ["ENV=production", "VERSION=1.2.3"]
  execute_command  = "chmod +x {{ .Path }}; sudo {{ .Vars }} {{ .Path }}"
}
```

Key options: `inline` (array of commands), `script` (single file), `scripts` (array of files), `environment_vars`, `execute_command`, `valid_exit_codes`, `expect_disconnect` (for reboots), `inline_shebang` (default `/bin/sh -e`).

### File

```hcl
provisioner "file" {
  source      = "config/nginx.conf"
  destination = "/tmp/nginx.conf"
}

# Then move to final location with shell provisioner
provisioner "shell" {
  inline = ["sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf"]
}
```

Upload files or directories. Upload to `/tmp` first, then use a shell provisioner to move to privileged locations. Set `direction = "download"` to fetch files from the machine.

### Ansible

```hcl
# Runs ansible-playbook from the host, connects to the machine via SSH
provisioner "ansible" {
  playbook_file   = "ansible/playbook.yml"
  galaxy_file     = "ansible/requirements.yml"
  extra_arguments = ["--extra-vars", "env=production"]
}

# Runs ansible-playbook locally on the machine (Ansible must be pre-installed)
provisioner "ansible-local" {
  playbook_file = "ansible/playbook.yml"
  role_paths    = ["ansible/roles/common", "ansible/roles/app"]
}
```

The `ansible` provisioner runs from the host; `ansible-local` copies files to the machine and runs there. Both require the `hashicorp/ansible` plugin.

## Post-Processors

Post-processors transform or publish artifacts after a build completes.

### Built-in Post-Processors

```hcl
build {
  sources = ["source.qemu.debian"]

  # Write a JSON manifest of all build artifacts
  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }

  # Generate checksums for output files
  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "output-debian/{{.BuildName}}_{{.ChecksumType}}.checksum"
  }

  # Compress artifacts into an archive
  post-processor "compress" {
    output = "output-debian/{{.BuildName}}.tar.gz"
  }
}
```

### Docker Post-Processor Chain

```hcl
build {
  sources = ["source.docker.app"]

  # Sequenced post-processors (output of one feeds the next)
  post-processors {
    post-processor "docker-tag" {
      repository = "myregistry.io/myapp"
      tags       = ["latest", "1.2.3"]
    }
    post-processor "docker-push" {}
  }
}
```

Use a `post-processors` block (plural) to chain post-processors sequentially where each receives the previous one's artifact. Use multiple standalone `post-processor` blocks for independent post-processing.

## Variables

```hcl
variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the build"
}

variable "ssh_password" {
  type      = string
  sensitive = true     # suppressed from CLI output and logs
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "packer"
  }
}
```

**Precedence (highest to lowest):** CLI `-var` flag, CLI `-var-file` flag, `*.auto.pkrvars.hcl` (alphabetical), `PKR_VAR_<name>` env var, `default` in variable block.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Missing required plugin` on build | `packer init` not run or plugin not declared in `required_plugins` | Run `packer init .`; check `required_plugins` block matches the source type |
| `Error initializing builder` | Plugin version mismatch or corrupted install | `packer init -upgrade .` to re-download; delete `$HOME/.config/packer/plugins/` and re-init |
| `Timeout waiting for SSH` | VM not booting, wrong SSH credentials, or firewall blocking | Check `boot_command` for typos, verify `ssh_username`/`ssh_password`, increase `ssh_timeout`, enable `-debug` |
| `Waiting for SSH` hangs (QEMU) | No KVM acceleration, or `accelerator` set wrong | Verify `/dev/kvm` exists (`ls -la /dev/kvm`); set `accelerator = "kvm"` or fall back to `"tcg"` (slow) |
| `VNC connection failed` (QEMU) | Port conflict or headless mode issue | Set `headless = true` for CI; check nothing else binds the VNC port range |
| Build succeeds but AMI not found | Wrong region or AMI name collision | AMI names must be unique per region; use `{{timestamp}}` in `ami_name` |
| `AccessDenied` on AWS build | Insufficient IAM permissions | Builder needs `ec2:RunInstances`, `ec2:CreateImage`, `ec2:DescribeImages`, etc. |
| `Post-processor failed` | Docker daemon not running or registry auth missing | `docker login` before build; verify `systemctl status docker` |
| Provisioner script fails silently | Exit code not propagated | Check `valid_exit_codes`; use `set -euo pipefail` in scripts; check `inline_shebang` |
| `Checksum did not match` on ISO download | Corrupt download or wrong checksum value | Verify checksum from upstream; `iso_checksum = "sha256:<hash>"` or `iso_checksum = "file:<url>"` |

## Pain Points

- **Plugin unbundling (Packer 1.14+):** As of August 2025, official plugins (Amazon, Docker, QEMU, Ansible, etc.) are no longer bundled with the Packer binary. Every template needs a `required_plugins` block and `packer init` before building. Old templates that assumed built-in builders will break without this block.
- **BSL license:** Packer switched from MPL 2.0 to BSL 1.1 starting with v1.9.3 (August 2023). The license permits non-competitive production use but prohibits offering Packer as a hosted service that competes with HashiCorp. Unlike Terraform, there is no community fork of Packer.
- **QEMU boot_command timing:** The `boot_command` sends keystrokes to the VM console, and timing depends on VM boot speed. Fragile `<wait>` durations cause intermittent failures. Use `http_directory` to serve preseed/kickstart/cloud-init configs and minimize interactive boot steps.
- **No state tracking:** Unlike Terraform, Packer has no state file. Each `packer build` creates a fresh artifact. There is no way to update an existing image in place; you rebuild from scratch and replace the old artifact.
- **Large ISO caching:** ISOs are cached in `./packer_cache/` by default (relative to the working directory). In CI, this means a fresh download every run unless `PACKER_CACHE_DIR` points to a persistent volume.
- **Sensitive variables in logs:** While `sensitive = true` hides values from CLI output, Packer debug logs (`PACKER_LOG=1`) may still include sensitive data. Never commit debug logs.
- **Provisioner ordering:** Provisioners execute strictly in declaration order. A misplaced `file` provisioner before the directory exists, or an `ansible` provisioner before Python is installed, fails without helpful context.

## See Also

- `terraform` -- Infrastructure as code; Packer builds images that Terraform deploys
- `ansible` -- Configuration management; commonly used as a Packer provisioner
- `kvm-libvirt` -- KVM/QEMU hypervisor management; runs images Packer builds
- `docker` -- Container runtime; Packer's Docker builder creates container images

## References

See `references/` for:
- `docs.md` -- official documentation links
- `common-patterns.md` -- practical HCL2 examples for QEMU, Docker, AWS, and multi-source builds
