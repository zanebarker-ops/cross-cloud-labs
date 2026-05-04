# 05 — Troubleshooting

Real failures hit during the first deploy (2026-05-04), with the diagnosis and the fix. Read this if a `terraform plan`/`apply` errors and the message looks unfamiliar.

## CRLF in `.env`

**Symptoms:**

```
.env: line 1: $'\r': command not found
.env: line 6: $'\r': command not found
…
Error: unable to build authorizer for Resource Manager API: could not configure
AzureCli Authorizer: the provided subscription ID "5ed51d12-...\r" is not known
```

The `\r` chars at the end of every line get embedded into env vars. `ARM_SUBSCRIPTION_ID` becomes `5ed51d12...\r` and ARM rejects it.

**Diagnosis:**

```bash
file .env
# Bad:  ASCII text, with CRLF line terminators
# Good: ASCII text
```

**Fix (one-shot):**

```bash
sed -i 's/\r$//' /mnt/c/repos/github/cross-cloud-labs/.env
```

**Permanent prevention:** edit `.env` only with WSL-side editors (vim, nano in WSL, VS Code with `files.eol = "\n"`). Avoid Windows Notepad and any editor that defaults to CRLF.

**Workaround when you can't fix the file** (read-only filesystem, etc.): pipe through `tr -d '\r'` at source time:

```bash
set -a && source <(tr -d '\r' < ../../../.env) && set +a
```

## Azure VM `SkuNotAvailable` — capacity-restricted

**Symptoms:**

```
Error: creating Linux Virtual Machine … unexpected status 409 (409 Conflict)
with error: SkuNotAvailable: The requested VM size for resource 'Following SKUs
have failed for Capacity Restrictions: Standard_B1s' is currently not available
in location 'eastus'.
```

Azure throttles small-VM SKU capacity per region. `B1s` was capacity-restricted, `B2s` was capacity-restricted, `DS1_v2` was capacity-restricted — the entire BS family + DSv2 family in `eastus` was constrained on 2026-05-04.

**Diagnosis — query before guessing:**

```bash
# 1. List unrestricted gen2-capable SKUs in the region
az vm list-skus --location <region> --resource-type virtualMachines -o json \
  | python3 -c "
import json, sys
for s in json.load(sys.stdin):
  if s.get('restrictions'): continue
  caps = {c['name']: c['value'] for c in (s.get('capabilities') or [])}
  if 'V2' not in caps.get('HyperVGenerations',''): continue
  if caps.get('CpuArchitectureType','') != 'x64': continue
  try:
    if int(caps.get('vCPUs','99')) > 4: continue
  except: continue
  print(s['name'], caps.get('vCPUs','?'), 'vCPU /', caps.get('MemoryGB','?'), 'GB')
"

# 2. Cross-reference with quota
az vm list-usage --location <region> -o tsv | grep -E "v7|v6|BS Family"
```

A SKU you can deploy is one that's both:
- in the unrestricted list (capacity available right now), AND
- in a family with quota > 0

**Fix that's worked:** switch region to `eastus2` where multiple v7 D-/F-/E-families are unrestricted with default 10 vCPU quota. The lab's current default is `Standard_D2als_v7` (AMD, 2 vCPU / 4 GB, gen2-capable, ~$0.041/hr).

## Azure VM `OperationNotAllowed` — quota = 0

**Symptoms:**

```
Error: creating Linux Virtual Machine … OperationNotAllowed: Operation could
not be completed as it results in exceeding approved standardBasv2Family Cores
quota. Additional details - … Current Limit: 0
```

The SKU itself has capacity but the family has zero approved quota on this subscription. Bsv2/Basv2/Bpsv2 families default to 0 quota — they need a manual request via the Azure portal.

**Fix:** pick a SKU in a family with default 10 vCPU quota (most v7 families, BS, DSv3, DSv4 — verify with `az vm list-usage`). Or request quota via Azure portal Quotas page (slow async approval).

## Azure VPN GW — `NonAzSkusNotAllowedForVPNGateway`

**Symptoms:**

```
Error: creating Virtual Network Gateway … NonAzSkusNotAllowedForVPNGateway:
VpnGw1-5 non-AZ SKUs are no longer supported for VPN gateways. Only
VpnGw1-5AZ SKUs can be created going forward.
```

Microsoft retired the non-AZ VPN GW SKUs in 2026-05.

**Fix:** use the `*AZ` variant. The lab default is `VpnGw1AZ` (~$0.225/hr, was VpnGw1 ~$0.19/hr — ~18% cost bump, no behaviour difference for this lab).

## Azure VPN GW — `VmssVpnGatewayPublicIpsMustHaveZonesConfigured`

**Symptoms:**

```
Error: creating Virtual Network Gateway … VmssVpnGatewayPublicIpsMustHaveZonesConfigured:
Standard Public IPs associated with VPN Gateways with AZ VPN skus must have
zones configured.
```

AZ-SKU VPN gateways require a zoned Public IP. A bare Standard Public IP without `zones` is rejected.

**Fix:** add `zones = ["1","2","3"]` to the `azurerm_public_ip`. Force-new on `zones` — if you already created a zoneless PIP, Terraform plans a destroy + recreate. The lab's `main.tf` already sets this.

## Azure ARM 429 — `RetryableError: A retryable error occurred`

**Symptoms:**

```
Error: updating Network Security Group Association for Subnet … unexpected
status 429 (Too Many Requests) with error: RetryableError: A retryable error occurred.
```

ARM throttling on too many parallel writes during a large apply. Common during the first apply of the lab when ~12 resources are being created in parallel.

**Fix:** just **re-run `terraform apply`**. TF retries the failed resource against existing state. No code change needed.

## Azure NIC — `context deadline exceeded`

**Symptoms:**

```
Error: creating Network Interface … polling after CreateOrUpdate: context deadline exceeded
```

The NIC was probably created in Azure but the Terraform polling timed out before the API confirmed completion.

**Diagnosis:** check Azure for the NIC. If it exists, TF state is out of sync.

**Fix:**

```bash
terraform import azurerm_network_interface.workload \
  "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/networkInterfaces/<nic-name>"
terraform plan        # confirm only "missing" resources will be created
terraform apply
```

## `az` CLI on the wrong subscription

**Symptoms:**

```
ERROR: (ResourceGroupNotFound) Resource group 'rg-cross-cloud-labs-vpn-eastus2'
could not be found.
```

…right after a successful apply that explicitly created that RG.

**Diagnosis:**

```bash
az account show --query "{name:name, id:id}" -o table
# If id != ARM_SUBSCRIPTION_ID, you're on the wrong sub.
```

`az login` from your interactive workstation session likely defaulted to a different subscription than the one Terraform's SP env vars target.

**Fix (per-command):** add `--subscription "$ARM_SUBSCRIPTION_ID"` to the `az` invocation.

**Fix (session-wide):** briefly log in as the SP:

```bash
az login --service-principal \
  -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" --output none
# … run validation commands …
# (your interactive `az login` is preserved — `az logout` only logs out the SP)
```

## AWS IAM — `AccessDenied: iam:CreateRole`

**Symptoms:**

```
Error: creating IAM Role … AccessDenied: User: arn:aws:iam::123456789012:user/terraform-deployer
is not authorized to perform: iam:CreateRole on resource:
arn:aws:iam::123456789012:role/ccl-vpns2s-workload-role
```

The deployer's inline policy `cross-cloud-labs-iam-scoped` only authorizes IAM actions on ARNs prefixed with `cross-cloud-labs-` — but the role above is named `ccl-vpns2s-workload-role` (short prefix used elsewhere in the lab).

**Fix:** rename to use the long prefix: `cross-cloud-labs-vpn-s2s-workload-role`. The lab's `main.tf` already does this. **Lesson:** non-IAM resources (VPC, SG, EC2) can use any prefix you like; **IAM resources must use the `cross-cloud-labs-` prefix** to satisfy the deployer policy.

Also load-bearing: `iam:Tag*` permissions on instance profiles and policies. The AWS provider's `default_tags` block tags resources at create time, so missing `iam:TagInstanceProfile` causes Create to fail mid-flight even though `CreateInstanceProfile` itself is allowed.

## VPN tunnel won't come up after Phase 3

**Symptoms:** `connectionStatus` stays `Connecting` or `NotConnected` for >5 min. AWS reports tunnel 1 `DOWN` with `IPSEC IS DOWN`.

**Top causes:**

| Likely cause | Check |
|---|---|
| PSK mismatch | Both sides use the same `aws_tunnel1_psk` value — copy via `terraform output -raw aws_tunnel1_psk`. Manually retyping is the #1 way to mismatch. |
| Wrong AWS tunnel public IP in Azure LNG | `terraform output aws_tunnel1_address` (NOT tunnel 2). The two tunnel IPs are unrelated. |
| BGP peering address mismatch | Azure LNG's `bgp_settings.bgp_peering_address` must be `169.254.21.1`; AWS's tunnel inside CIDR is `169.254.21.0/30`. Locked in lab variables — only an issue if you customized. |
| ASN mismatch | Azure 65010, AWS 65020. Lab defaults — only an issue if you customized. |
| Customer Gateway points at wrong Azure IP | AWS-side `azure_gw_public_ip` in tfvars must match `terraform output azure_gw_public_ip` from Azure. |

**Validation queries** (after both sides settle):

```bash
# Azure
az network vpn-connection show -g rg-cross-cloud-labs-vpn-eastus2 -n cn-azure-aws \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --query "{state:connectionStatus, ingress:ingressBytesTransferred, egress:egressBytesTransferred}" -o table

# AWS
aws ec2 describe-vpn-connections --region us-east-1 \
  --query 'VpnConnections[].VgwTelemetry[].{Tunnel:OutsideIpAddress,Status:Status,Routes:AcceptedRouteCount,Msg:StatusMessage}' \
  --output table
```

Healthy state: Azure `Connected`, ingress + egress non-zero; AWS tunnel 1 `UP`, `1 BGP ROUTES` accepted (Azure's VNet CIDR), tunnel 2 `DOWN` (expected — never wired to Azure in v1).

## Cross-cloud `ping` fails despite `Connected` tunnel

**Top causes:**

- **Azure NSG ingress rule missing** — the workload NSG must allow ICMP from `10.20.0.0/16`. Lab default does this.
- **AWS Security Group ingress rule missing** — workload SG must allow ICMP from `10.10.0.0/16`. Lab default does this.
- **Workload route table not propagating from VGW** — AWS workload RT must have `aws_vpn_gateway_route_propagation` enabled. Lab default does this.
- **VPN GW BGP not accepting Azure prefix** — verify with `az network vpn-gateway show` → `bgpSettings`. If routes aren't being learned, BGP keepalives may be flowing without a real session establish — restart the connection (`az network vpn-connection list-routes-table-summary` then re-run apply).

## Generic Terraform-state debugging

```bash
# Show every resource currently in state
terraform state list

# Show details for one resource
terraform state show <addr>

# Forcibly refresh state from cloud (read-only on state, writes the result)
terraform apply -refresh-only -auto-approve

# Plan with verbose logging (debug)
TF_LOG=DEBUG terraform plan 2>&1 | tee /tmp/tf-plan-debug.log
```

State drift symptoms (resource exists but plan says "to add") usually mean a previous apply errored mid-flight and didn't save state for that resource. Use `terraform import` to re-attach.

## What now

- Tunnel up but want to stop the meter: **[04 — Tearing down](04-tearing-down.md)**.
- Want to know what each running resource costs: **[06 — Cost](06-cost.md)**.
