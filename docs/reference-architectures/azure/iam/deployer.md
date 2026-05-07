# Azure deployer identity (`cross-cloud-labs-tf`)

Source-of-truth doc for the Azure service principal that Terraform runs as in this repo. Counterpart to `docs/reference-architectures/aws/iam/deployer.md`.

## Identity

| Field | Value |
|---|---|
| Type | App registration + service principal (client secret auth) |
| Display name | `cross-cloud-labs-tf` |
| Auth method | Client ID + client secret |
| Secret lifetime | 1 year |
| Bootstrap method | manual `az ad sp create-for-rbac` (one-time) |
| Lifecycle | manual; not managed by Terraform (chicken-and-egg) |

## Permissions

Single role assignment:

| Role | Scope | Why |
|---|---|---|
| `Contributor` | `/subscriptions/<SUB_ID>` | Full resource management within the subscription, no RBAC mutation, no Microsoft Entra (AAD) changes. |

Trade-off vs RG-scoping: subscription-scope means a compromised secret can stand up resources anywhere in the sub. Acceptable because (a) this sub is single-user / lab-only, (b) the budget alert caps spend, and (c) Terraform needs to create and destroy RGs as part of normal lab flow.

`Contributor` does **not** grant:
- RBAC role assignment changes (`Microsoft.Authorization/roleAssignments/write`)
- Microsoft Entra directory operations (creating users, SPs, app regs)
- Subscription / billing scope changes

If a lab needs role-assignment authoring (e.g., assigning a managed identity a role on a storage account), grant the SP **`User Access Administrator`** at the same scope, or — better — assign that role only on the specific resource. Document it in the lab README when added.

## Tags (App Registration)

Service principals don't carry Azure resource tags; the underlying App Registration object does:

```
owner:zane
project:cross-cloud-labs
managed_by:manual
purpose:terraform-deployer
```

## Credentials

- `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` stored in `/mnt/c/repos/github/cross-cloud-labs/.env` (gitignored).
- Loaded via `set -a && source .env && set +a` before `terraform <cmd>`.
- AzureRM provider auto-detects these env vars; no provider block credentials needed.
- **Never** commit, paste into chat, or place in `*.tfvars`.

## Rotation

Secret expires 1 year after creation. Rotate on or before expiry, or immediately if exposed.

```bash
# 1. Create a new secret, capture its value.
az ad app credential reset \
  --id "$ARM_CLIENT_ID" \
  --append \
  --years 1 \
  --display-name "rotated-$(date +%Y-%m-%d)"

# 2. Update .env with the new secret.
# 3. Smoke test (see below).
# 4. After 24h with no breakage, remove the old credential:
az ad app credential list --id "$ARM_CLIENT_ID"
az ad app credential delete --id "$ARM_CLIENT_ID" --key-id <old-keyId>
```

## Companion controls

- **Tenant root account**: protected by MFA / Conditional Access on the human user; SP cannot use those flows.
- **Budget**: `cross-cloud-labs-monthly` at $10 USD, 80% threshold notification to `me@zanebarker.com`. (Azure equivalent of the AWS billing alarms.)

## What this identity does NOT do

- Does not assign roles (no `Microsoft.Authorization/*/write`).
- Does not modify Microsoft Entra (AAD).
- Does not have an interactive login.
- Is not used by CI; this repo is local-apply only.

## Cost

$0. App registrations, SPs, and role assignments are free.

## Smoke test

```bash
set -a && source .env && set +a
az login --service-principal \
  --username "$ARM_CLIENT_ID" \
  --password "$ARM_CLIENT_SECRET" \
  --tenant "$ARM_TENANT_ID"
az account show --query "{sub:name, id:id, user:user.name}" -o table
az logout
# Expected: user.name == ARM_CLIENT_ID, id == ARM_SUBSCRIPTION_ID
```
