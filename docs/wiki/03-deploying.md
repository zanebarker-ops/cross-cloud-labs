# 03 — Deploying

End-to-end walkthrough of bringing up the cross-cloud site-to-site VPN. The same pattern (apply A → paste outputs → apply B → paste outputs → apply A again) applies to any future cross-cloud lab.

**Total time: ~50–60 minutes** dominated by Azure VPN GW provisioning (≈45 min) and AWS VPN Connection (≈4–7 min).

**Total running cost while up: ~$0.33/hr** (~$2.65/day with 8h teardown). See [Cost](06-cost.md).

## Prerequisites checklist

- [ ] Workstation prereqs from [01 — Getting started](01-getting-started.md)
- [ ] `.env` at repo root with both clouds' creds, no CRLF
- [ ] `aws sts get-caller-identity` returns `terraform-deployer`
- [ ] `az login --service-principal …` succeeds; `az account show --subscription "$ARM_SUBSCRIPTION_ID"` returns the lab sub
- [ ] SSH keypair generated (Azure VM auth)

## Phase 1 — Azure (Side A, no peer info yet)

Builds VNet, GatewaySubnet, Public IP, **VPN Gateway** (the slow one), workload subnet + NSG + NIC + VM. Does **not** create the Local Network Gateway or Connection (those need AWS info).

```bash
cd azure/labs/vpn-site-to-site
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars      # paste your SSH public key, leave create_connection = false

set -a && source ../../../.env && set +a
terraform init
terraform plan -out=phase1.tfplan
terraform apply phase1.tfplan
```

**Time: 30–45 min** (VPN GW dominates). The VM itself takes ~1 min once provisioned.

Capture outputs (paste into the AWS lab next):

```bash
terraform output azure_gw_public_ip       # → 72.153.32.253 (example)
terraform output azure_bgp_asn            # → 65010
terraform output azure_vnet_cidr          # → 10.10.0.0/16
terraform output azure_workload_private_ip # → 10.10.1.4
```

## Phase 2 — AWS (Side B, full apply)

Builds VPC, subnets, IGW, **VGW + VPN Connection**, Customer Gateway (pointing at Azure's public IP), route tables with VGW propagation, SG, EC2 + IAM/SSM role.

```bash
cd ../../../aws/labs/vpn-site-to-site
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars      # paste azure_gw_public_ip from Phase 1

set -a && source ../../../.env && set +a
terraform init
terraform plan -out=phase2.tfplan
terraform apply phase2.tfplan
```

**Time: ~6 min** (VPN Connection at ~4 min is the bottleneck; the rest is parallel).

Capture outputs (paste into Azure for Phase 3):

```bash
terraform output aws_tunnel1_address          # → 34.201.175.30 (example)
terraform output -raw aws_tunnel1_psk         # SENSITIVE — print directly to pipe, don't echo
terraform output aws_workload_private_ip      # → 10.20.1.88
# aws_tunnel2_address is created (HA) but never wired to Azure in v1
```

The PSK is sensitive — avoid putting it on the screen if you can. The cleanest pattern is to capture it directly into the Azure tfvars without printing:

```bash
PSK=$(terraform output -raw aws_tunnel1_psk)
# write it into the Azure tfvars in one shot — see Phase 3 below
```

## Phase 3 — Azure (Side A, round 2)

Adds the Local Network Gateway (representing AWS's tunnel 1 endpoint) and the Connection (binds VNG ↔ LNG, carries PSK + BGP-enable). The tunnel comes up within 1–2 min after this completes.

Update `azure/labs/vpn-site-to-site/terraform.tfvars`:

```hcl
admin_ssh_public_key = "ssh-ed25519 …"   # already there from Phase 1
create_connection    = true              # flip from false
aws_tunnel1_address  = "34.201.175.30"   # from Phase 2 output
aws_tunnel1_psk      = "<paste from Phase 2 -raw output>"
# aws_vgw_asn  = 65020          # default in variables.tf
# aws_vpc_cidr = "10.20.0.0/16" # default in variables.tf
```

Then:

```bash
cd ../../../azure/labs/vpn-site-to-site
set -a && source ../../../.env && set +a
terraform plan -out=phase3.tfplan         # 2 to add: LNG + Connection
terraform apply phase3.tfplan
```

**Time: ~1 min for resources to apply, then 1–2 min for the tunnel to negotiate.**

## Validation

```bash
# Azure side — connection state + byte counters
set -a && source .env && set +a
az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" --output none
az network vpn-connection show \
  -g rg-cross-cloud-labs-vpn-eastus2 \
  -n cn-azure-aws \
  --subscription "$ARM_SUBSCRIPTION_ID" \
  --query "{state:connectionStatus, ingress:ingressBytesTransferred, egress:egressBytesTransferred}" -o table
# Expected: state=Connected, both byte counters > 0 (BGP keepalives)
```

```bash
# AWS side — tunnel 1 UP, tunnel 2 DOWN (expected), 1 BGP route accepted
aws ec2 describe-vpn-connections --region us-east-1 \
  --query 'VpnConnections[].VgwTelemetry[].{Tunnel:OutsideIpAddress,Status:Status,Routes:AcceptedRouteCount,Msg:StatusMessage}' \
  --output table
```

If both sides agree (Azure Connected, AWS tunnel 1 UP with 1 accepted route), BGP has exchanged prefixes and the tunnel is live.

## Cross-cloud ping (optional end-to-end test)

Reach into either workload VM and ping the other side's private IP. The Azure VM has no public IP — use Bastion or an in-VNet jump host. The AWS EC2 has a public IPv4 only because SSM bootstrap needs IGW egress; SG denies inbound — use SSM Session Manager:

```bash
aws ssm start-session --target i-064e28a8c86894844 --region us-east-1
# inside the SSM session:
ping 10.10.1.4              # Azure workload private IP
```

Reverse path (Azure VM → AWS EC2 at 10.20.1.88) requires Bastion or jump on the Azure side. Same expected behaviour: bidirectional ICMP succeeds.

## Why three phases

- **Local state both sides** (no shared remote backend) means no automatic data flow between roots. Outputs on one side become inputs on the other via manual paste.
- **Azure Phase 1 can't include the LNG/Connection** because the LNG needs the AWS tunnel public IP, which is generated when the VPN Connection is created on the AWS side.
- **AWS Phase 2 needs Azure's public IP** for the Customer Gateway.
- **Azure Phase 3 needs AWS's tunnel public IP and PSK** for the LNG and Connection.

A single root with both providers would collapse this to one apply, but at the cost of either: a remote state backend (excluded by the cost-first rule), or weird `for_each` ordering tricks that defeat the simplicity goal of the lab.

## What now

- Tunnel up, work session over: **[04 — Tearing down](04-tearing-down.md)**.
- Tunnel didn't come up: **[05 — Troubleshooting](05-troubleshooting.md)**.
- Want to know what's burning money right now: **[06 — Cost](06-cost.md)**.
