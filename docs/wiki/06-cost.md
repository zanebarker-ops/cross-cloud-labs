# 06 — Cost

Cost is the **#1 constraint** of this repo ([CLAUDE.md hard rule #2](../../.claude/CLAUDE.md)). $100 AWS promo credit must last ~6 months; the Azure tenant is real money with no credit. Every billable resource is documented with its hourly + monthly cost in its ref-arch doc; this page is the system-level summary.

## What's running when the VPN lab is up

Per-resource cost (us-east-1 / eastus2, 2026-05 pricing):

| Resource | Cloud | $ / hr | $ / mo (24×7) | Notes |
|---|---|---|---|---|
| VPN Gateway VpnGw1AZ | Azure | 0.225 | ~163 | **Dominant cost** |
| VPN Connection (1 pair, both tunnels) | AWS | 0.050 | ~36 | Charged regardless of tunnel state |
| Standard Public IP (zoned) | Azure | 0.005 | ~3.60 | One per VPN GW; required by VpnGw1AZ |
| EC2 public IPv4 (workload) | AWS | 0.005 | ~3.65 | Default-assigned IP for SSM bootstrap |
| `Standard_D2als_v7` VM (eastus2) | Azure | 0.041 | ~30 | AMD 2 vCPU / 4 GB; current default |
| `t3.micro` EC2 | AWS | 0.0104 | ~7.50 | Free-tier eligible |
| OS disks (combined, 30 GB Standard_LRS Azure + 8 GB gp3 AWS) | both | ~0.003 | ~5 | |
| **Total while running** | | **~0.34** | **~248** | |

VGW itself ($0/hr — charged via VPN Connection) and Customer Gateway / Local Network Gateway ($0/hr) don't add to the meter. Data transfer over the tunnel is metered (AWS $0.09/GB out) but negligible for ICMP/SSH.

## Daily / monthly math

| Pattern | Daily cost | Monthly cost |
|---|---|---|
| Apply, work 8h, teardown nightly | ~**$2.65/day** | ~$80/mo |
| Apply, work 4h, teardown nightly | ~**$1.50/day** | ~$45/mo |
| Apply, **forget to teardown** (24/7) | **~$8.20/day** | **~$248/mo** |

Within the $100 AWS credit budget:
- AWS share of the running cost: ~$0.07/hr (VPN Connection + EC2 + public IPv4 + EBS).
- 8h teardown-nightly Mon–Fri ≈ $0.56/day AWS-side ≈ $14/mo ≈ ~7 months of credit.
- 24/7 ≈ $1.68/day AWS-side ≈ $50/mo ≈ ~2 months of credit.

The Azure side has **no credit** — every $0.27/hr while up is real money.

## Why daily teardown is non-negotiable

The dominant Azure-side resources (VPN Gateway, Public IP) **cannot be paused** — there's no "stopped" state for them. The only way to stop the meter is to delete them.

The dominant AWS-side resource (VPN Connection) **also cannot be paused** — it's billed as long as the resource exists.

A "stopped" workload VM still incurs disk + public IP cost on both clouds. Stopping isn't enough; only destroy.

## Stranded-resource list (the things that quietly burn money)

Sorted by hourly damage if forgotten:

| Resource | $/hr | Most common stranding |
|---|---|---|
| Azure VPN Gateway | 0.225 | A `terraform destroy` errored mid-flight; re-run the destroy. |
| AWS VPN Connection | 0.050 | Same — partial destroy. |
| AWS NAT Gateway | 0.045+ | Not in this lab. If you add one to a future lab, ensure `destroy.sh` covers it. |
| Public IPs (any kind, any cloud) | 0.005 each | Most likely to be missed. EIPs, default-assigned EC2 public IPs, Azure PIPs not associated with a parent. |
| Managed disks | 0.003+ each | A VM destroyed without `delete_os_disk_on_deletion` set; mitigated by lab default. |

Sanity-check after teardown:

```bash
# AWS
aws ec2 describe-vpcs --region us-east-1 \
  --filters Name=tag:project,Values=cross-cloud-labs --output table
aws ec2 describe-vpn-connections --region us-east-1 \
  --filters Name=tag:project,Values=cross-cloud-labs --output table
aws ec2 describe-addresses --region us-east-1 \
  --filters Name=tag:project,Values=cross-cloud-labs --output table

# Azure (after SP login)
az resource list --subscription "$ARM_SUBSCRIPTION_ID" \
  --tag project=cross-cloud-labs --query "[].{name:name, type:type, rg:resourceGroup}" -o table
```

A clean teardown = empty tables on both.

## Out-of-scope by cost

These are explicitly **refused** by the project rules and reviewer subagents. Do not introduce them without an explicit budget conversation:

| Service | Why excluded |
|---|---|
| Azure ExpressRoute | $700+/mo minimum |
| AWS Direct Connect | $200+/mo minimum |
| Dedicated hosts / reserved capacity (either cloud) | Standing commitment, anti-teardown |
| AWS GuardDuty / Config / Security Hub | Per-event billing scales unpredictably with infrastructure churn |
| Azure Defender for Cloud / Sentinel | Same |
| Premium tier of any service when Standard works | Budget rule (preferred over re-tier later) |

vWAN Hub is in scope but **flagged**: secured-hub starts at ~$0.40/hr — a future vWAN lab needs an explicit cost-impact statement before scaffolding.

## Per-PR cost-impact statement

Any PR that adds a billable resource must include a **cost-impact statement** in the PR description: hourly rate, monthly rate (24×7), and the dominant cost driver named explicitly. Reviewer subagents (`code-reviewer.md`, `aws-expert.md`, `azure-expert.md`) all prompt on this.

## Budget controls in place

- **AWS billing alarms** (CloudWatch in us-east-1): `billing-25`, `billing-50`, `billing-90` USD against the $100 promo, notifying SNS topic `billing-alerts` → email.
- **Azure budget**: `cross-cloud-labs-monthly` at $10 USD with 80% threshold notification.

These are the safety net, not the strategy. The strategy is daily teardown; the alarms are there to catch the day daily teardown fails.

## What now

- Ready to deploy: **[03 — Deploying](03-deploying.md)**.
- Done for the day: **[04 — Tearing down](04-tearing-down.md)**.
