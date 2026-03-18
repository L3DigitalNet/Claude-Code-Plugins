---
name: cloud-cli
description: >
  Cloud platform CLI tools — AWS CLI, Azure CLI, and Google Cloud CLI (gcloud)
  installation, authentication, profile/project management, common operations,
  and troubleshooting. Covers the three major cloud providers from a sysadmin
  perspective.
  MUST consult when using AWS CLI, Azure CLI, or gcloud commands.
triggerPhrases:
  - "aws cli"
  - "azure cli"
  - "gcloud"
  - "cloud cli"
  - "aws configure"
  - "az login"
  - "gcloud init"
  - "cloud platform"
  - "AWS"
  - "Azure"
  - "Google Cloud"
  - "GCP"
  - "cloud credentials"
  - "cloud storage"
  - "S3"
  - "az storage"
  - "gsutil"
globs:
  - "**/.aws/config"
  - "**/.aws/credentials"
  - "**/.azure/**"
last_verified: "2026-03"
---

## Identity

| Property | AWS CLI | Azure CLI | Google Cloud CLI |
|----------|---------|-----------|------------------|
| **Binary** | `aws` | `az` | `gcloud`, `gsutil` (legacy), `bq` |
| **Config path** | `~/.aws/config` | `~/.azure/config` (INI format) | `~/.config/gcloud/` |
| **Credentials** | `~/.aws/credentials` | `~/.azure/` (token cache, managed internally) | `~/.config/gcloud/application_default_credentials.json` |
| **Config env override** | `AWS_CONFIG_FILE`, `AWS_SHARED_CREDENTIALS_FILE` | `AZURE_CONFIG_DIR` (default `~/.azure`) | `CLOUDSDK_CONFIG` (default `~/.config/gcloud`) |
| **Install (Debian/Ubuntu)** | `sudo snap install aws-cli --classic` or manual zip installer | `curl -sL https://aka.ms/InstallAzureCLIDeb \| sudo bash` | `sudo apt-get install google-cloud-cli` |
| **Install (RHEL/Fedora)** | `sudo snap install aws-cli --classic` or manual zip installer | `sudo dnf install azure-cli` (after adding MS repo) | `sudo dnf install google-cloud-cli` |
| **Version check** | `aws --version` | `az version` | `gcloud version` |
| **Update** | Re-run installer or `sudo snap refresh aws-cli` | `az upgrade` | `gcloud components update` |

**Key environment variables per provider:**

- **AWS**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_DEFAULT_REGION`, `AWS_REGION`, `AWS_PROFILE`, `AWS_DEFAULT_OUTPUT`, `AWS_PAGER`, `AWS_CA_BUNDLE`, `AWS_ENDPOINT_URL`, `AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE`
- **Azure**: `AZURE_CONFIG_DIR`, `AZURE_DEFAULTS_GROUP`, `AZURE_DEFAULTS_LOCATION`, `AZURE_CORE_OUTPUT`, `AZURE_CORE_COLLECT_TELEMETRY`, `HTTP_PROXY`, `HTTPS_PROXY`
- **GCloud**: `CLOUDSDK_CORE_PROJECT`, `CLOUDSDK_COMPUTE_REGION`, `CLOUDSDK_COMPUTE_ZONE`, `CLOUDSDK_ACTIVE_CONFIG_NAME`, `CLOUDSDK_CONFIG`, `GOOGLE_APPLICATION_CREDENTIALS`

## Quick Start

Install the AWS CLI, configure credentials, and verify with a simple command.

```bash
# Install on Linux (snap -- auto-updating)
sudo snap install aws-cli --classic

# Or install via official zip (x86_64)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure default credentials and region
aws configure
# Prompts for: Access Key ID, Secret Access Key, Default region, Output format

# Verify
aws sts get-caller-identity
```

The `aws configure` command writes to `~/.aws/credentials` (keys) and `~/.aws/config` (region, output format). For SSO-based auth, use `aws configure sso` instead.

## Key Operations

### AWS CLI

| Task | Command |
|------|---------|
| Authenticate (IAM keys) | `aws configure` |
| Authenticate (SSO) | `aws sso login --profile my-profile` |
| Assume role | `aws sts assume-role --role-arn arn:aws:iam::123456:role/MyRole --role-session-name session1` |
| Who am I | `aws sts get-caller-identity` |
| List S3 buckets | `aws s3 ls` |
| Upload to S3 | `aws s3 cp file.tar.gz s3://my-bucket/` |
| Download from S3 | `aws s3 cp s3://my-bucket/file.tar.gz ./` |
| Sync directory to S3 | `aws s3 sync ./local-dir s3://my-bucket/prefix/` |
| Presigned URL | `aws s3 presign s3://my-bucket/file --expires-in 3600` |
| List EC2 instances | `aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType]' --output table` |
| Start/stop instance | `aws ec2 start-instances --instance-ids i-1234567890abcdef0` |
| List IAM users | `aws iam list-users --query 'Users[].UserName' --output table` |
| Create access key | `aws iam create-access-key --user-name myuser` |
| Set output format | `--output json\|table\|text\|yaml` |
| Filter with JMESPath | `--query 'Items[?Status==\`active\`].Name'` |

### Azure CLI

| Task | Command |
|------|---------|
| Interactive login | `az login` |
| Device code login | `az login --use-device-code` |
| Service principal login | `az login --service-principal -u CLIENT_ID -p SECRET --tenant TENANT_ID` |
| Certificate login | `az login --service-principal -u CLIENT_ID --certificate /path/to/cert.pem --tenant TENANT_ID` |
| Managed identity login | `az login --identity` |
| Who am I | `az account show` |
| Set subscription | `az account set --subscription "Sub Name or ID"` |
| List resource groups | `az group list --output table` |
| Create resource group | `az group create --name mygroup --location eastus` |
| List VMs | `az vm list --output table` |
| Start/stop VM | `az vm start --resource-group mygroup --name myvm` |
| Upload to blob | `az storage blob upload --account-name myacct --container-name mycontainer --file local.txt --name remote.txt` |
| List blobs | `az storage blob list --account-name myacct --container-name mycontainer --output table` |
| List AD users | `az ad user list --query '[].{Name:displayName, UPN:userPrincipalName}' --output table` |
| Set default group | `az config set defaults.group=mygroup` |
| Set output format | `--output json\|jsonc\|yaml\|yamlc\|table\|tsv\|none` |
| Filter with JMESPath | `--query '[?location==\`eastus\`].name'` |

### Google Cloud CLI

| Task | Command |
|------|---------|
| Initialize | `gcloud init` |
| User login | `gcloud auth login` |
| Service account auth | `gcloud auth activate-service-account --key-file=sa-key.json` |
| Application Default Credentials | `gcloud auth application-default login` |
| Who am I | `gcloud auth list` |
| Set project | `gcloud config set project PROJECT_ID` |
| Set region/zone | `gcloud config set compute/region us-central1` |
| List VM instances | `gcloud compute instances list` |
| Create VM | `gcloud compute instances create myvm --zone=us-central1-a --machine-type=e2-micro` |
| SSH to VM | `gcloud compute ssh myvm --zone=us-central1-a` |
| Start/stop VM | `gcloud compute instances stop myvm --zone=us-central1-a` |
| List GCS buckets | `gcloud storage ls` |
| Upload to GCS | `gcloud storage cp file.tar.gz gs://my-bucket/` |
| Download from GCS | `gcloud storage cp gs://my-bucket/file.tar.gz ./` |
| Sync to GCS | `gcloud storage rsync ./local-dir gs://my-bucket/prefix/` |
| List IAM policy | `gcloud projects get-iam-policy PROJECT_ID` |
| Grant IAM role | `gcloud projects add-iam-policy-binding PROJECT_ID --member='user:user@example.com' --role='roles/viewer'` |
| Create service account | `gcloud iam service-accounts create sa-name --display-name="My SA"` |
| Set output format | `--format=json\|yaml\|table\|csv\|text\|value` |
| Filter results | `--filter="zone:us-central1-a AND status=RUNNING"` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Unable to locate credentials` (AWS) | No credentials configured, or wrong profile active | Run `aws configure` or export `AWS_PROFILE`; verify `~/.aws/credentials` exists |
| `ExpiredTokenException` (AWS) | STS temporary credentials or SSO session expired | Re-run `aws sso login --profile <name>` or refresh the assumed role |
| `The config profile could not be found` (AWS) | Typo in profile name or missing `[profile X]` block | Check `~/.aws/config` for exact profile name spelling |
| `AADSTS700016: Application not found` (Azure) | Wrong client/app ID for service principal | Verify the `--username` (client ID) matches the app registration |
| `Please run 'az login' to setup account` (Azure) | No active session or token expired | Run `az login`; for CI use `az login --service-principal` |
| `The subscription could not be found` (Azure) | Wrong subscription selected or insufficient permissions | Run `az account list --output table` and `az account set -s <id>` |
| `ERROR: (gcloud.auth) Your current active account does not have any valid credentials` (GCloud) | Revoked or expired credentials | Run `gcloud auth login` or `gcloud auth activate-service-account` |
| `The default credentials were not found` (GCloud ADC) | No Application Default Credentials configured | Run `gcloud auth application-default login` or set `GOOGLE_APPLICATION_CREDENTIALS` |
| `Could not determine project` (GCloud) | No default project set | Run `gcloud config set project PROJECT_ID` or pass `--project` flag |
| Region/zone not set (any) | Default region/zone not configured | AWS: `aws configure set region us-east-1`; Azure: `az config set defaults.location=eastus`; GCloud: `gcloud config set compute/region us-central1` |
| `AccessDenied` / `403 Forbidden` (any) | IAM permissions insufficient for the operation | Check the identity with the "who am I" command, then review IAM policies attached to it |
| API quota/rate limit exceeded (any) | Too many requests in a short period | Implement backoff/retry; request quota increase via the provider's console |

## Pain Points

- **Credential management**: Each provider uses a different credential model. AWS stores long-lived keys in plain text at `~/.aws/credentials`; rotate keys regularly and prefer SSO or IAM roles over static keys. Azure tokens are managed internally and refresh automatically, but service principals require manual secret rotation. GCloud stores OAuth refresh tokens under `~/.config/gcloud/`; use `gcloud auth revoke` to clean up sessions.

- **Profile/subscription/project switching**: AWS uses `--profile` flag or `AWS_PROFILE` env var. Azure uses `az account set --subscription`. GCloud uses named configurations (`gcloud config configurations activate <name>`). In all three, forgetting which context is active leads to operating on the wrong account. Use shell prompt integrations (e.g., `starship`, `oh-my-zsh` cloud plugins) to show the active profile.

- **Output formatting and filtering**: AWS defaults to JSON and supports `--query` (JMESPath syntax) plus `--output json|table|text|yaml`. Azure also uses JMESPath with `--query` and supports `--output json|jsonc|table|tsv|yaml|yamlc|none`. GCloud uses a different syntax: `--format=json|table|csv|yaml|value|text` for formatting and `--filter` (Python-like expressions, not JMESPath) for server-side filtering. Mixing up the filter syntaxes across providers is a constant source of errors.

- **Pagination**: AWS CLI auto-paginates by default (disable with `--no-paginate` or `AWS_PAGER=""`). Azure paginates with `--top` and continuation tokens for some commands. GCloud paginates automatically but some commands need `--limit` or `--page-size`. Long result sets can time out or produce unexpected truncation.

- **Cost awareness**: CLI operations that create resources incur real charges with no built-in cost confirmation. Unlike the web consoles, CLIs rarely show cost estimates before provisioning. Use `--dry-run` where available (AWS EC2), review pricing pages, and set up billing alerts in all three providers before running create/provision commands in production accounts.

- **gsutil deprecation**: Google now recommends `gcloud storage` commands over the legacy `gsutil` tool. `gcloud storage` is faster (up to 94% on downloads) and supports newer features like soft delete and managed folders. Existing `gsutil` scripts can run through a compatibility shim, but new scripts should use `gcloud storage cp`, `gcloud storage ls`, etc.

## See Also

- **terraform** -- Infrastructure as code using all three cloud providers
- **ansible** -- Configuration management with cloud provider modules
- **curl-wget** -- Direct API calls to cloud provider REST endpoints

## References
See `references/` for:
- `docs.md` -- Official documentation links for AWS CLI, Azure CLI, and Google Cloud CLI
- `cheatsheet.md` -- Side-by-side comparison of equivalent operations across all three providers
- `common-patterns.md` -- SSO login, service account auth, storage uploads, instance management, output filtering
