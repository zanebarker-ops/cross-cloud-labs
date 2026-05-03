# Lab: vpn-site-to-site (AWS side)

Cross-cloud IPSec site-to-site VPN between Azure (East US) and AWS (us-east-1) using the AWS Virtual Private Gateway. This directory is the **AWS side** of the lab. The Azure side lives at [`azure/labs/vpn-site-to-site/`](../../../azure/labs/vpn-site-to-site/).

The cross-cloud reference doc is at [`docs/reference-architectures/cross-cloud/vpn-site-to-site/`](../../../docs/reference-architectures/cross-cloud/vpn-site-to-site/) (owned by the Azure session). The AWS-only reference is at [`docs/reference-architectures/aws/networking/vpn-site-to-site.md`](../../../docs/reference-architectures/aws/networking/vpn-site-to-site.md).

## What this creates

| Resource | Purpose |
|---|---|
| `aws_vpc` (10.20.0.0/16) | Lab VPC |
| `aws_subnet` public (10.20.0.0/24) | Reserved for future bastion/NAT |
| `aws_subnet` workload (10.20.1.0/24) | Holds the test EC2; receives BGP-propagated Azure routes |
| `aws_internet_gateway` | Egress for SSM Session Manager |
| `aws_vpn_gateway` (ASN 65020) | AWS-side IPSec endpoint |
| `aws_customer_gateway` | Points at the Azure VPN Gateway public IP, ASN 65010 |
| `aws_vpn_connection` | BGP, both tunnels created (Azure consumes tunnel 1 in v1) |
| `aws_vpn_gateway_route_propagation` | Auto-installs the Azure VNet route into the workload route table |
| `aws_security_group` | ICMP ingress from `var.azure_vnet_cidr` only; egress all |
| `aws_iam_role` + SSM-core attachment | Lets you reach the EC2 via `aws ssm start-session`. Named `cross-cloud-labs-vpn-s2s-workload-role` — IAM resources require the full `cross-cloud-labs-` prefix per [`docs/reference-architectures/aws/iam/deployer.md`](../../../docs/reference-architectures/aws/iam/deployer.md) |
| `aws_instance` t3.micro AL2023 | Ping target from the Azure side |
| `random_password` | Generates the tunnel-1 PSK |

## Locked cross-cloud parameters

These are agreed with the Azure session. **Do not change without pinging the other session.**

| | Value |
|---|---|
| AWS region | `us-east-1` |
| AWS VPC CIDR | `10.20.0.0/16` |
| AWS VGW BGP ASN | `65020` |
| Azure region | East US |
| Azure VNet CIDR | `10.10.0.0/16` |
| Azure BGP ASN | `65010` |
| Routing | BGP, no static routes |
| Tunnels | Both created on AWS, Azure consumes tunnel 1 only in v1 |

## Three-phase apply order

This lab uses local Terraform state on both sides — no `terraform_remote_state`. The user shuttles outputs between sides manually.

1. **Azure round 1** — Azure session applies their tree first, producing `azure_gw_public_ip`, `azure_bgp_asn`, `azure_vnet_cidr`.
2. **AWS apply (this dir)** — paste those into `terraform.tfvars` here, then apply. Produces `aws_tunnel1_address`, `aws_tunnel1_psk`, `aws_vgw_asn`, `aws_vpc_cidr`.
3. **Azure round 2** — Azure session pastes the four AWS outputs into their tfvars and applies the Local Network Gateway + Connection.

Workload VMs (this side's `aws_instance.workload`, Azure's B1s) can apply at any phase — they do not depend on tunnel state.

## Usage

```bash
# Repo root
cp .env.example .env   # fill in AWS creds (see top-level README)
set -a && source .env && set +a

cd aws/labs/vpn-site-to-site
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and paste azure_gw_public_ip from Azure round 1

terraform init
terraform apply

# Hand these four outputs to the Azure session for round 2
terraform output aws_tunnel1_address
terraform output aws_vgw_asn
terraform output aws_vpc_cidr
terraform output -raw aws_tunnel1_psk    # sensitive
```

## Verifying the tunnel

After Azure round 2 has applied:

```bash
# AWS-side BGP / tunnel status
aws ec2 describe-vpn-connections \
  --filters Name=tag:lab,Values=vpn-site-to-site \
  --query 'VpnConnections[].VgwTelemetry'

# Connect to the AWS workload instance via SSM (no SSH key needed)
aws ssm start-session --target "$(terraform output -raw aws_workload_instance_id)"

# From inside the AWS instance, ping the Azure workload's private IP
ping <azure_workload_private_ip>
```

## Teardown

```bash
./destroy.sh
```

This wraps `terraform destroy -auto-approve` against the local state. Always teardown nightly — see cost note below.

> Note: the repo-root `teardown-all.sh` currently only walks `labs/` (legacy layout). It will be updated in a follow-up to walk both `aws/labs/` and `azure/labs/`.

## Cost (AWS side)

| Item | Rate | Notes |
|---|---|---|
| VPN Gateway (VGW) | free | No standing charge |
| VPN Connection | $0.05/hr | ~$1.20/day if left up |
| t3.micro EC2 | $0.0104/hr | Free-tier eligible |
| Public IPv4 on EC2 | $0.005/hr | Charged on attached IPv4s |
| EBS gp3 8GB | ~$0.001/hr | Negligible |
| Data over VPN | $0.09/GB out | Negligible for ICMP |

**~$1.30–$1.50/day if forgotten.** With nightly teardown: cents.

## Gotchas

- **PSK character set**: AWS only accepts `[A-Za-z0-9._]` and the PSK cannot start with `0`. The `random_password` resource here is configured accordingly. If you hand-roll a PSK, mind those rules.
- **BGP ASN reservations**: AWS reserves several ASNs (e.g. 7224, 9059, 17493, 22697, etc.). 65010 / 65020 are private and safe.
- **Tunnel 1 only**: only tunnel 1's PSK is pinned (via `random_password`). Tunnel 2 has an AWS-default PSK and is unused in v1. To bring it up later, pin `tunnel2_preshared_key` and add a second Azure Connection.
- **Workload subnet is technically internet-attached**: it has a default route to the IGW so the EC2 can reach SSM endpoints over the public internet. The SG locks ingress to ICMP from the Azure VNet CIDR only, so it is not publicly reachable, but it is *not* an air-gapped private subnet. A future improvement is interface VPC endpoints for SSM (~$22/mo) so we can drop the IGW route.
- **Route propagation**: `aws_vpn_gateway_route_propagation` is on the workload route table only. The public route table does not learn Azure routes — by design.
