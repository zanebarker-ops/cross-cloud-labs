# AWS deployer identity (`terraform-deployer`)

Source-of-truth doc for the IAM user that Terraform runs as in this repo.

## Purpose

Single non-human identity used by all labs in `aws/labs/*` and the cross-cloud labs in `labs/*`. Equivalent to the Azure SP defined in `.env.example` (`ARM_CLIENT_ID` etc.) — both are credential-based identities consumed by Terraform from the local `.env`.

## Identity

| Field | Value |
|---|---|
| Type | IAM user (programmatic access only) |
| Name | `terraform-deployer` |
| Console access | disabled |
| MFA | not enabled (incompatible with long-lived access keys in non-interactive use) |
| Region (default) | `us-east-1` |
| Bootstrap method | manual click-ops in AWS Console (one-time) |
| Lifecycle | manual; not managed by Terraform (chicken-and-egg) |

## Permissions

Two policies, attached directly to the user.

### 1. AWS-managed: `PowerUserAccess`

Grants full access to AWS services *except* IAM, Organizations, and Account. Chosen because:

- Single-user sandbox account, $100 credit ceiling, billing alarms in place — blast radius is bounded.
- Lets new labs use new AWS services without policy edits each time.
- Excludes the dangerous services (IAM/Org/Account) by default.

Trade-off: broader than strictly needed. Acceptable for a personal lab; would not be acceptable in a shared or production account.

### 2. Inline: `cross-cloud-labs-iam-scoped`

Grants narrow IAM permissions so Terraform can create lab-scoped roles (e.g., VPN logging role, EC2 instance profile) without holding `iam:*`.

**Allow** these IAM actions, but only on resources whose name starts with `cross-cloud-labs-`:

- Role lifecycle: `CreateRole`, `DeleteRole`, `GetRole`, `ListRoles`, `UpdateRole`, `UpdateAssumeRolePolicy`, `TagRole`, `UntagRole`, `PassRole`
- Role policies: `AttachRolePolicy`, `DetachRolePolicy`, `PutRolePolicy`, `DeleteRolePolicy`, `GetRolePolicy`, `ListRolePolicies`, `ListAttachedRolePolicies`
- Service-linked roles: `CreateServiceLinkedRole`
- Customer-managed policies: `CreatePolicy`, `DeletePolicy`, `GetPolicy`, `ListPolicies`, `CreatePolicyVersion`, `DeletePolicyVersion`, `GetPolicyVersion`, `ListPolicyVersions`, `TagPolicy`, `UntagPolicy`
- Instance profiles: `CreateInstanceProfile`, `DeleteInstanceProfile`, `GetInstanceProfile`, `AddRoleToInstanceProfile`, `RemoveRoleFromInstanceProfile`, `TagInstanceProfile`, `UntagInstanceProfile`

> **Tag actions are load-bearing.** The AWS Terraform provider's `default_tags` block applies tags at *create* time on every taggable resource. Without `iam:Tag*` permissions on instance profiles and policies, the `Create*` calls fail with `AccessDenied` on the implicit tagging step — even though `Create*` itself is allowed. Discovered while applying `aws/labs/vpn-site-to-site` (2026-05-03): `TagInstanceProfile`/`UntagInstanceProfile` were missing from the original policy. `TagPolicy`/`UntagPolicy` added at the same time as a preventative for the next lab that creates a customer-managed policy.

**Deny** any `iam:*` against the deployer user (`arn:aws:iam::*:user/terraform-deployer`), so a compromised key cannot escalate by rotating its own creds, attaching `AdministratorAccess` to itself, deleting the deny statement, etc. Access-key actions (`CreateAccessKey`, `UpdateAccessKey`, `DeleteAccessKey`) are evaluated against the parent user ARN, so the user-level Deny covers them — IAM access keys are not addressable as standalone ARNs.

### Naming convention (load-bearing)

**Every IAM role, policy, and instance profile created by Terraform in this repo MUST be named with prefix `cross-cloud-labs-`.** The inline policy enforces this: roles named outside the prefix will fail to create. Suggested per-lab naming: `cross-cloud-labs-<lab>-<purpose>`, e.g. `cross-cloud-labs-vpn-s2s-flowlogs`.

## Tags

Applied at create time:

```
owner       = zane
project     = cross-cloud-labs
managed_by  = manual
purpose     = terraform-deployer
```

## Credentials

- Access key + secret stored in `/mnt/c/repos/github/cross-cloud-labs/.env` (gitignored).
- Loaded via `set -a && source .env && set +a` before `terraform <cmd>`.
- One active key at a time.
- **Never** commit, paste into chat, or place in `*.tfvars`.

## Rotation

Rotate every 90 days, or immediately if the laptop is lost or `.env` is exposed.

```
# In Console: IAM → Users → terraform-deployer → Security credentials
# 1. Create access key #2.
# 2. Update .env on the workstation with the new key/secret.
# 3. Run `aws sts get-caller-identity` to confirm.
# 4. Mark old key Inactive.
# 5. After 24h with no breakage, delete old key.
```

## Companion controls

- **Root account**: MFA enabled, no access keys, not used for daily work.
- **Billing alarms** (CloudWatch in us-east-1): `billing-25`, `billing-50`, `billing-90` USD against the $100 promo credit, notifying SNS topic `billing-alerts` → `me@zanebarker.com`.

## What this identity does NOT do

- Does not manage itself (Deny on `arn:aws:iam::*:user/terraform-deployer`).
- Does not touch Organizations, Account, or Billing settings (excluded by `PowerUserAccess`).
- Does not have console access.
- Is not used by CI; this repo is local-apply only.

## Cost

$0. IAM users, policies, and access keys are free. Billing alarms via CloudWatch are free at this volume (under the 10-alarm free tier).

## Smoke test

```bash
set -a && source .env && set +a
aws sts get-caller-identity
# Expected: Arn ends with :user/terraform-deployer
```
