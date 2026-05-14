# 01 — Getting started

What you need on the workstation, what you need set up in each cloud, and how the local `.env` ties them together.

## Workstation prerequisites

| Tool | Why | Install |
|---|---|---|
| Terraform ≥ 1.6 | Lab applies use locked provider versions | [hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| Azure CLI (`az`) | Manual SP bootstrap, post-deploy validation, quota / SKU lookups | [docs.microsoft.com/cli/azure/install](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| AWS CLI v2 (`aws`) | Post-deploy validation, AMI lookups | userspace install: `curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip && python3 -m zipfile -e /tmp/awscliv2.zip /tmp/ && /tmp/aws/install -i ~/.local/aws-cli -b ~/.local/bin` |
| `jq` | Required by `.claude/hooks/block-main-write.sh` (the PreToolUse hook) | `apt install jq` (or your package manager) |
| Bash + Python 3 | For `set -a && source ../../../.env`, the CRLF stripper, the userspace zip extractor | usually pre-installed on Linux/WSL |

The repo runs on Linux / WSL2 (Windows). Windows-native `.env` files end up with CRLF line endings — see [Troubleshooting](05-troubleshooting.md#crlf-in-env).

## Azure side — service principal `cross-cloud-labs-tf`

One-time bootstrap. Detailed spec: [`docs/reference-architectures/azure/iam/deployer.md`](../reference-architectures/azure/iam/deployer.md).

```bash
# Create the SP with Contributor on the subscription you want labs to land in.
az login                                    # interactive, as a human
az account set --subscription <YOUR_SUB_ID>
az ad sp create-for-rbac \
  --name cross-cloud-labs-tf \
  --role Contributor \
  --scopes /subscriptions/<YOUR_SUB_ID> \
  --years 1
```

Capture from the JSON output:
- `appId` → `ARM_CLIENT_ID`
- `password` → `ARM_CLIENT_SECRET`
- `tenant` → `ARM_TENANT_ID`
- Plus your `<YOUR_SUB_ID>` → `ARM_SUBSCRIPTION_ID`

## AWS side — IAM user `terraform-deployer`

One-time click-ops in the AWS Console. Detailed spec: [`docs/reference-architectures/aws/iam/deployer.md`](../reference-architectures/aws/iam/deployer.md).

- IAM → Users → Create user `terraform-deployer`, programmatic access only (no console)
- Attach managed policy `PowerUserAccess`
- Attach inline policy `cross-cloud-labs-iam-scoped` (full JSON in the ref-arch doc) — narrowly grants IAM actions on ARNs prefixed `cross-cloud-labs-*`, and explicitly Denies any `iam:*` against the deployer user itself
- Create one access key, capture access key ID + secret

## `.env` — single source of credentials for both clouds

Lives at the repo root. **Gitignored.** Loaded by every `terraform plan`/`apply` and every `destroy.sh` via `set -a && source ../../../.env && set +a`.

Template: [`.env.example`](../../.env.example). Real `.env` looks like:

```bash
# AWS
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# Azure
ARM_CLIENT_ID=<sp-app-id>
ARM_CLIENT_SECRET=<sp-secret>
ARM_TENANT_ID=<tenant-id>
ARM_SUBSCRIPTION_ID=<subscription-id>
```

If you copied / edited the file on Windows, strip CRLF: `sed -i 's/\r$//' .env`. (See [Troubleshooting](05-troubleshooting.md#crlf-in-env) for the symptoms — `subscription ID "xxxx\r" is not known` etc.)

## Smoke tests

Before touching any lab, confirm both identities work:

```bash
# Load .env into the current shell
set -a && source .env && set +a

# AWS
aws sts get-caller-identity
# Expected: Arn ends with :user/terraform-deployer

# Azure (briefly log the SP in for CLI access; needed for post-deploy queries
# since interactive `az login` likely points to a different subscription)
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" --output none
az account show --subscription "$ARM_SUBSCRIPTION_ID" --query "{sub:name, id:id, user:user.name}" -o table
# Expected: user.name == ARM_CLIENT_ID, id == ARM_SUBSCRIPTION_ID
```

## Workstation SSH key (only if running the VPN lab)

The Azure workload VM uses SSH-key auth. If you don't have a key earmarked for this:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/cross-cloud-labs-vpn-azure-vm -N "" \
  -C "cross-cloud-labs-vpn-azure-vm"
```

Pass the public key to the lab via `terraform.tfvars`:

```hcl
admin_ssh_public_key = "ssh-ed25519 AAAA... cross-cloud-labs-vpn-azure-vm"
```

(Pasted, not file-referenced — the variable is `string`.)

## What now

- First-time read: **[02 — Architecture](02-architecture.md)** to understand what's where.
- Just want to deploy the VPN lab: **[03 — Deploying](03-deploying.md)**.
