---
name: terraform
description: >
  Terraform and OpenTofu infrastructure as code: HCL syntax, provider configuration,
  resource management, state operations, modules, workspaces, plan/apply workflow,
  import, and troubleshooting. Covers both HashiCorp Terraform and the OpenTofu fork.
  MUST consult when installing, configuring, or troubleshooting terraform.
triggerPhrases:
  - terraform
  - opentofu
  - tofu
  - HCL
  - infrastructure as code
  - IaC
  - terraform plan
  - terraform apply
  - terraform state
  - terraform import
  - tfstate
  - terraform module
  - terraform provider
  - terraform workspace
  - terraform destroy
  - terraform init
  - .tf files
  - terraform cloud
  - terragrunt
last_verified: "2026-03"
globs:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.tf.json"
  - "**/.terraform.lock.hcl"
  - "**/terraform.tfstate"
  - "**/terraform.tfstate.backup"
---

## Identity

| Field | Value |
|-------|-------|
| Binaries | `terraform` (HashiCorp, BSL 1.1 license since v1.6) / `tofu` (OpenTofu, MPL 2.0, Linux Foundation) |
| Config file | `~/.terraformrc` (Linux/macOS) / `%APPDATA%\terraform.rc` (Windows). OpenTofu: `~/.tofurc` or `$XDG_CONFIG_HOME/opentofu/tofurc` |
| Working dir data | `.terraform/` — providers, modules, backend state cache (created by `init`) |
| State file | `terraform.tfstate` (local default), `terraform.tfstate.backup` (previous state) |
| Workspace state | `terraform.tfstate.d/<workspace>/terraform.tfstate` |
| Lock file | `.terraform.lock.hcl` — pins provider versions and hashes; commit to VCS |
| Plugin cache | `~/.terraform.d/plugin-cache` (set via `plugin_cache_dir` in CLI config or `TF_PLUGIN_CACHE_DIR`) |
| Provider search paths (Linux) | `~/.terraform.d/plugins`, `~/.local/share/terraform/plugins`, `/usr/local/share/terraform/plugins` |
| Key env vars | `TF_VAR_<name>` (input variables), `TF_LOG` (TRACE/DEBUG/INFO/WARN/ERROR/OFF), `TF_LOG_PATH`, `TF_DATA_DIR`, `TF_PLUGIN_CACHE_DIR`, `TF_WORKSPACE`, `TF_INPUT=false` (CI), `TF_IN_AUTOMATION`, `TF_CLI_ARGS`/`TF_CLI_ARGS_<cmd>`, `TF_CLI_CONFIG_FILE`, `TF_STATE_PERSIST_INTERVAL` |

## Quick Start

```bash
# Install Terraform (Debian/Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Initialize a working directory (download providers/modules)
terraform init

# Preview changes before applying
terraform plan
```

## Key Operations

| Task | Command |
|------|---------|
| Init | `terraform init` — download providers, modules, configure backend. `-upgrade` to update provider versions. `-migrate-state` when changing backends. |
| Validate | `terraform validate` — syntax and internal consistency check (no API calls) |
| Format | `terraform fmt` — rewrite `.tf` files to canonical style. `-check` for CI. `-recursive` for subdirectories. |
| Plan | `terraform plan` — preview changes. `-out=plan.tfplan` to save. `-replace="aws_instance.web"` to force recreation. `-target=module.vpc` for partial plans. |
| Apply | `terraform apply` — execute changes. `terraform apply plan.tfplan` for saved plans. `-auto-approve` to skip confirmation (CI only). |
| Destroy | `terraform destroy` — tear down all managed resources. `-target` for selective destruction. |
| Import (CLI) | `terraform import aws_instance.web i-1234567890abcdef0` — bring existing resource into state. |
| Import (block, 1.5+) | Declarative `import {}` blocks in HCL. `terraform plan -generate-config-out=generated.tf` auto-generates resource config. |
| State list | `terraform state list` — enumerate all resources in state. |
| State show | `terraform state show aws_instance.web` — detailed attributes of one resource. |
| State mv | `terraform state mv aws_instance.old aws_instance.new` — rename/move resources in state. |
| State rm | `terraform state rm aws_instance.web` — remove resource from state without destroying it. |
| State pull/push | `terraform state pull` / `terraform state push` — read/write raw state (use carefully). |
| Output | `terraform output` — display outputs. `-json` for machine parsing. `terraform output <name>` for single value. |
| Providers | `terraform providers` — list required providers. `terraform providers lock` to update lock file for multiple platforms. |
| Workspace | `terraform workspace list\|new\|select\|delete\|show` — manage named workspaces. |
| Console | `terraform console` — interactive expression evaluator against current state. |
| Graph | `terraform graph` — DOT-format dependency graph (pipe to `dot -Tpng` for visualization). |
| Force-unlock | `terraform force-unlock <LOCK_ID>` — manually release a stuck state lock. |
| Replace (modern taint) | `terraform apply -replace="resource.name"` — force destroy+recreate. Preferred over deprecated `terraform taint`. |

## Core Workflow
1. **Write** — define infrastructure in `.tf` files (HCL)
2. **`terraform init`** — initialize working directory, download providers/modules, configure backend
3. **`terraform plan`** — generate and review execution plan
4. **`terraform apply`** — execute the plan; Terraform updates state to track real resources
5. **Iterate** — modify config, re-plan, re-apply

### Remote State Backends
State should live remotely for team use. Common backends (all support locking unless noted):

| Backend | Storage | Locking | Notes |
|---------|---------|---------|-------|
| `s3` | AWS S3 | DynamoDB table or S3-native (`use_lockfile = true`, TF 1.10+) | Most common; encrypt with `encrypt = true` |
| `gcs` | Google Cloud Storage | Native | Uses service account or ADC |
| `azurerm` | Azure Blob Storage | Native blob lease | Supports OIDC and AAD auth |
| `consul` | Consul KV store | Native | Good for HashiCorp stack users |
| `pg` | PostgreSQL | Advisory locks | Simple, self-hosted option |
| `kubernetes` | K8s Secret | Native | State stored as a Secret in a namespace |
| `http` | Any HTTP endpoint | Optional (REST locking) | Flexible but requires custom server |
| `cos` | Tencent Cloud Object Storage | Native | China-region deployments |
| `oss` | Alibaba Object Storage | Native | China-region deployments |
| `remote` | HCP Terraform / Terraform Enterprise | Native | Full SaaS platform with runs, policies |

**HCP Terraform (formerly Terraform Cloud)**: SaaS platform for remote runs, state management, policy enforcement (Sentinel/OPA), and VCS-driven workflows. Free tier supports up to 500 managed resources.

## HCL Essentials

### Resources and Data Sources
```hcl
resource "aws_instance" "web" {       # managed resource -- Terraform creates/updates/deletes
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = var.instance_type
}

data "aws_ami" "ubuntu" {             # data source -- read-only lookup
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-*"]
  }
}
```

### Variables, Outputs, Locals
```hcl
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Must be a t2 or t3 instance type."
  }
}

output "instance_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP of the web instance"
  sensitive   = false    # set true to suppress in CLI output (still in state)
}

locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

### Providers and Terraform Block
```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"         # pessimistic constraint: >= 5.0, < 6.0
    }
  }
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}
```

### Meta-Arguments
- **`count`** — create N copies: `count = var.enable ? 1 : 0` (conditional creation)
- **`for_each`** — iterate over map/set: `for_each = toset(["web", "api", "worker"])` (preferred over count for named instances)
- **`depends_on`** — explicit dependency when Terraform can't infer it
- **`lifecycle`** — `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`
- **`provider`** — select a non-default provider alias

### Dynamic Blocks
```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port   = ingress.value.from
    to_port     = ingress.value.to
    protocol    = ingress.value.protocol
    cidr_blocks = ingress.value.cidrs
  }
}
```

### Moved Blocks (Refactoring, 1.1+)
```hcl
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}
```
Renames/moves resources in state without destroy+recreate. Also works for module refactoring.

### Import Blocks (1.5+)
```hcl
import {
  to = aws_instance.web
  id = "i-1234567890abcdef0"
}
```
Declarative import; pair with `terraform plan -generate-config-out=generated.tf` to auto-generate the resource config.

### Ephemeral Values (Terraform 1.10+)
Ephemeral input variables, output variables, and ephemeral resources are not persisted to state or plan files. Use for short-lived tokens, session IDs, or secrets that should never be stored.

### Write-Only Arguments (Terraform 1.11+)
Resource arguments marked write-only accept ephemeral values and are never stored in state. Versioned via companion `*_wo_version` attributes to trigger updates.

## State Management
- **Remote backends** (see table above) — store state centrally with locking to prevent concurrent writes
- **State locking** — automatic on supported backends; prevents two `apply` runs from corrupting state simultaneously
- **`terraform state mv`** — rename resources or move between modules without destroy; use `moved` blocks for version-controlled refactoring
- **`terraform state rm`** — remove from state without destroying infrastructure (useful for hand-off)
- **`terraform import`** (or import blocks) — bring existing infrastructure under management
- **`terraform apply -replace`** — force recreation (replaces deprecated `taint`/`untaint`)
- **`terraform state pull | jq .`** — inspect raw state JSON
- **State surgery** — last resort; always take a backup first: `cp terraform.tfstate terraform.tfstate.manual-backup`

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Error acquiring the state lock` | Concurrent run or crashed process left lock | Check for other running processes; `terraform force-unlock <LOCK_ID>` if confirmed safe |
| `Error: Cycle` in plan | Circular dependency between resources | Review `depends_on` and implicit references; break the cycle by restructuring |
| `Could not satisfy plugin requirements` | Provider version constraint mismatch | Check `required_providers` constraints; `terraform init -upgrade` |
| Plan shows unexpected destroy+recreate | Force-new attribute changed (e.g., AMI, name) | Review plan; use `lifecycle { ignore_changes }` if drift is acceptable |
| `Error: Resource already exists` on apply | Resource created outside Terraform or stale state | Import the resource or remove from state and re-create |
| `Provider produced inconsistent result` | Provider bug or eventual consistency | Retry; if persistent, pin to a working provider version |
| State drift (real infra differs from state) | Manual changes outside Terraform | `terraform plan` to detect; apply to reconcile or reimport |
| `Backend configuration changed` on init | Backend block modified without migration | `terraform init -migrate-state` to move state to new backend |
| Import fails with wrong ID format | Provider expects a specific ID format | Check provider docs for import ID format (ARN, name, composite with `/`) |

## Pain Points
- **State file contains secrets** — resource attributes (passwords, keys, connection strings) are stored in plain text in state. Always use remote backends with encryption (S3 `encrypt = true`, OpenTofu state encryption). The `sensitive` flag only hides values from CLI output, not from state.
- **Terraform vs OpenTofu licensing** — HashiCorp changed Terraform's license from MPL 2.0 to BSL 1.1 in v1.6 (Aug 2023). OpenTofu forked from the last MPL version and remains open source under the Linux Foundation. Both use HCL and share most provider compatibility. OpenTofu adds unique features: client-side state encryption (1.7+), `removed` blocks, loopable import blocks, provider-defined functions, and early variable/locals evaluation (1.8+).
- **Module versioning** — registry modules use semver constraints (`version = "~> 3.0"`); git modules pin via `ref` (tag, branch, commit). Always pin versions; unpinned modules break on upstream changes.
- **Provider authentication** — each provider has its own auth mechanism (env vars, config files, instance profiles). Misconfigured auth is the most common `init` failure.
- **Large state performance** — state files with thousands of resources become slow to plan/apply. Split into smaller root modules or use `-target` for focused operations. Consider Terragrunt for multi-environment orchestration.
- **`-replace` vs `taint`** — `terraform taint` is deprecated. Use `terraform apply -replace="resource.name"` instead; it doesn't modify state until apply runs.
- **Terragrunt** — thin wrapper (by Gruntwork) for orchestrating multiple Terraform/OpenTofu modules across environments. Provides DRY config, dependency management, and remote state auto-configuration. Not part of Terraform itself but commonly used alongside it.

## See Also

- **ansible** — configuration management and orchestration; complements IaC provisioning
- **kubernetes** — container orchestration managed by Terraform providers
- **cloud-cli** — AWS/Azure/GCloud CLIs for ad-hoc operations alongside Terraform
- **packer** — build golden images that Terraform provisions infrastructure from
- **consul** — service discovery and KV store; Terraform has a Consul provider

## References
See `references/` for:
- `cheatsheet.md` — essential commands organized by workflow phase
- `common-patterns.md` — practical HCL examples for everyday patterns
- `terraform.tfvars.annotated` — annotated variable file with types, validation, and best practices
- `docs.md` — official documentation links
