# 04 — Tearing down

Daily teardown is **non-negotiable** ([CLAUDE.md hard rule #1](../../.claude/CLAUDE.md)). This page covers the per-lab destroy, the repo-wide teardown, the order both clouds destroy in, and the common hangs.

## Two ways to tear down

### Per-lab — when only one lab is up

```bash
cd <lab-dir>            # e.g. azure/labs/vpn-site-to-site
./destroy.sh
```

`destroy.sh` is a thin wrapper. It:

1. Resolves the lab dir and the repo root
2. Sources `.env` (with `set -a && source .env && set +a`)
3. Runs `terraform init -input=false -upgrade=false >/dev/null` (idempotent, ensures providers are present)
4. Runs `terraform destroy -auto-approve`

Each cloud's `destroy.sh` lives next to that side's lab files. The destroy.sh files are checked in.

### Repo-wide — when multiple labs are up

```bash
./teardown-all.sh        # from repo root
```

Walks every lab directory under `aws/labs/*` and `azure/labs/*` and runs each lab's `destroy.sh` in turn. Used end-of-day or when starting fresh.

## Order matters slightly

If both sides of a cross-cloud lab are up, **destroy AWS first, then Azure** in practice — but the ordering is more nuanced than that suggests:

- The two state files are independent. Either side can destroy first; neither needs the other.
- Azure's Connection retains a reference to the AWS tunnel public IP via the LNG — destroying the AWS-side VPN Connection invalidates that IP, but Azure doesn't care (the LNG still holds the literal IP value, the ARM API doesn't validate reachability on destroy).
- **AWS destroy is fast (~5 min)** so it gets out of the way first. **Azure destroy is slow (10–25 min)** dominated by the VPN Gateway delete.

The only ordering trap: if Azure-side destroy hangs on the Connection while the AWS-side Connection is still up, it's because of an in-flight IPSec re-key collision. Solution: just wait, or destroy AWS first.

## Resource-by-resource teardown order (TF dependency graph)

You don't sequence this manually — Terraform does. Documented here so destroy hangs are diagnosable.

### Azure side (10–25 min total)

```
Connection (cn-azure-aws)              ← Phase 3 resources first
LocalNetworkGateway (lng-aws-tunnel1)
VirtualNetworkGateway (vng-eastus2)    ← the slow one (10–20 min)
PublicIP (pip-vpngw)                   ← can't delete while VPN GW holds it
LinuxVirtualMachine (vm-azure-workload)
NetworkInterface (nic-azure-workload)
Subnet/NSG association
NetworkSecurityRule × 2
NetworkSecurityGroup
Subnet × 2 (workload, GatewaySubnet)
VirtualNetwork (vnet-eastus2)
ResourceGroup (rg-cross-cloud-labs-vpn-eastus2)
```

### AWS side (~5 min total)

```
Instance (workload EC2)                ← detaches first
SecurityGroup
IamInstanceProfile / IamRole / RolePolicyAttachment
VpnConnection                          ← ~1 min destroy
CustomerGateway
VpnGatewayAttachment
VpnGateway (VGW)
VpnGatewayRoutePropagation
RouteTable / RouteTableAssociation × N
Subnet × 2
InternetGateway
VPC
random_password.tunnel1_psk            ← TF-only, no API call
```

## Known teardown gotchas

- **Azure VPN GW takes 10–20 minutes to delete.** Plan for it. This is the bottleneck.
- **Azure Public IP can't delete while VPN GW holds it.** Terraform handles ordering implicitly via the `ip_configuration.public_ip_address_id` reference.
- **AWS VPN Connection must delete before VGW can detach.** Handled by the dependency between `aws_vpn_gateway_attachment` and `aws_vpn_connection`.
- **AWS VGW detach can hang** if a lingering VPN Connection or route propagation is not in state. Both should be managed by Terraform; if you ever modified them out-of-band, `terraform import` first or destroy the orphan in the console.
- **No soft-deleted resources.** No Key Vault, no Recovery Vault — so no purge-protection traps. If you add such resources to a future lab, configure `purge_protection_enabled = false` and `soft_delete_retention_days = 7` for lab-only.

## Stranded-resource watch (the things that quietly cost money if forgotten)

| Resource | Cost / hr | How it gets stranded |
|---|---|---|
| AWS Public IPv4 (any) | ~$0.005 each | EIPs explicitly created and not released; default-assigned EC2 public IPs after termination is incomplete |
| Azure Standard Public IP | ~$0.005 each | VPN GW PIP if VPN GW destroy errored mid-flight; orphaned NIC PIPs |
| AWS VPN Connection | ~$0.05 / hr | Connection still in state but VGW detached — usually a sign of a partial destroy |
| Azure VPN Gateway | ~$0.225 / hr | The big one. Destroy errored, retry the destroy. |
| AWS NAT Gateway | ~$0.045 / hr + $0.045/GB | None in this lab. If a future lab introduces it, **always** in destroy script. |
| Azure managed disks | ~$0.003+ / hr each | VM destroyed but disk's `delete_option` not set; mitigated by provider `delete_os_disk_on_deletion = true` (set in `versions.tf`) |

After a teardown, sanity-check both sides:

```bash
# AWS — list anything in the lab tag scope still standing
aws ec2 describe-vpcs --region us-east-1 \
  --filters Name=tag:project,Values=cross-cloud-labs --output table

aws ec2 describe-vpn-connections --region us-east-1 \
  --filters Name=tag:project,Values=cross-cloud-labs --output table
```

```bash
# Azure — list resources still tagged into the lab
set -a && source .env && set +a
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" --output none
az resource list --subscription "$ARM_SUBSCRIPTION_ID" \
  --tag project=cross-cloud-labs --query "[].{name:name, type:type, rg:resourceGroup}" -o table
```

A clean teardown returns empty tables on both.

## What if `destroy` errors

1. **Re-run the same `destroy.sh`.** Most errors are transient (ARM 429, AWS race conditions on detach).
2. **Re-run after a short wait.** `terraform destroy` again is idempotent; resources already gone are skipped, the rest get retried.
3. **If a resource is gone in the cloud but TF still thinks it's there**, `terraform state rm <addr>` and re-run.
4. **If a resource is in the cloud but not in state**, `terraform import <addr> <id>` and then `destroy`. (Hit this once during the eastus2 deploy when an ARM polling timeout left a NIC orphaned in state.)
5. **Last resort — RG delete (Azure only).** `az group delete -g <rg> --yes --subscription "$ARM_SUBSCRIPTION_ID"`. Wipes everything in the RG; Terraform state then needs `terraform state rm <every-azure-resource>` or a fresh init.

## What now

- Hit a destroy error: **[05 — Troubleshooting](05-troubleshooting.md)**.
- Want to redeploy: **[03 — Deploying](03-deploying.md)** from Phase 1.
