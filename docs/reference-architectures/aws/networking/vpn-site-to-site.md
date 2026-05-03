# AWS — Site-to-Site VPN (VGW)

> AWS-side reference for the cross-cloud Azure↔AWS IPSec VPN lab. The cross-cloud topology doc is at [`docs/reference-architectures/cross-cloud/vpn-site-to-site/`](../../cross-cloud/vpn-site-to-site/) (canonical for both sides). This doc is canonical for the AWS-only pieces.

## 1. Purpose

Establish a managed IPSec site-to-site VPN from an AWS VPC to an external customer site (in our lab, the "customer" is an Azure VNet). Used when:

- You need site-to-site connectivity but cannot justify Direct Connect cost.
- The remote side is on-prem, in a colo, or in another cloud.
- You want BGP-learned routing rather than static.

This lab uses a **Virtual Private Gateway (VGW)** attached directly to a single VPC. For multi-VPC or hub-and-spoke layouts, a **Transit Gateway (TGW) VPN attachment** is the equivalent — that is the experimental lab #3 and is out of scope here.

**Azure analogue**: VGW ≈ Azure VPN Gateway. Customer Gateway ≈ Local Network Gateway. VPN Connection ≈ Connection. Route propagation on a route table ≈ "Propagate gateway routes" toggle on a Route Table associated with a GatewaySubnet.

## 2. Diagram

```
                   AWS us-east-1                                 Azure East US
   ┌────────────────────────────────────────────┐         ┌──────────────────────────────┐
   │  VPC 10.20.0.0/16                          │         │  VNet 10.10.0.0/16           │
   │                                            │         │                              │
   │  ┌────────────────────┐                    │         │     ┌────────────────────┐   │
   │  │ workload subnet    │                    │         │     │ GatewaySubnet      │   │
   │  │ 10.20.1.0/24       │                    │         │     │ 10.10.255.0/27     │   │
   │  │                    │                    │         │     │                    │   │
   │  │  EC2 t3.micro      │                    │         │     │  VPN GW (VpnGw1)   │   │
   │  │  (AL2023, SSM)     │                    │         │     │  ASN 65010         │   │
   │  └────────┬───────────┘                    │         │     └────────┬───────────┘   │
   │           │ rt: 10.10.0.0/16 → VGW         │         │              │ rt → AWS via  │
   │           │      0.0.0.0/0   → IGW         │         │              │ Connection    │
   │           ▼                                │         │              ▼               │
   │      Route Table (propagation ON)          │         │     Local Network GW         │
   │           │                                │         │     target: AWS tunnel1_addr │
   │           ▼                                │         │     ASN 65020                │
   │      ┌──────────┐                          │         │     addr: 10.20.0.0/16       │
   │      │   VGW    │ ASN 65020                │         │              │               │
   │      └────┬─────┘                          │         │              │               │
   │           │ aws_vpn_gateway_attachment     │         │              │               │
   │           │                                │         │              │               │
   │      ┌────┴──────────┐                     │         │              │               │
   │      │ VPN Connection│ BGP, ipsec.1        │         │              │               │
   │      │  Tunnel 1  ◄──┼──── IPSec ──────────┼─────────┼──►  Connection (BGP, PSK)     │
   │      │  Tunnel 2  ◄──┼──── (HA, unused v1) │         │                              │
   │      └────┬──────────┘                     │         │                              │
   │           │                                │         │                              │
   │      ┌────┴────────────┐                   │         │                              │
   │      │ Customer Gateway│ ip = Azure GW IP  │         │                              │
   │      │                 │ ASN = 65010       │         │                              │
   │      └─────────────────┘                   │         │                              │
   └────────────────────────────────────────────┘         └──────────────────────────────┘
```

## 3. Components

| Resource type | Name pattern | Role |
|---|---|---|
| `aws_vpc` | `ccl-vpns2s-vpc` | 10.20.0.0/16 lab VPC |
| `aws_subnet` (public) | `ccl-vpns2s-public` | 10.20.0.0/24, reserved for future bastion/NAT |
| `aws_subnet` (workload) | `ccl-vpns2s-workload` | 10.20.1.0/24, holds test EC2; learns Azure route via VGW propagation |
| `aws_internet_gateway` | `ccl-vpns2s-igw` | Egress for SSM Session Manager |
| `aws_route_table` (public) | `ccl-vpns2s-rt-public` | 0.0.0.0/0 → IGW |
| `aws_route_table` (workload) | `ccl-vpns2s-rt-workload` | 0.0.0.0/0 → IGW; Azure CIDR learned via BGP propagation |
| `aws_vpn_gateway_route_propagation` | n/a | Enables route propagation onto workload RT |
| `aws_vpn_gateway` | `ccl-vpns2s-vgw` | AWS-side IPSec endpoint, ASN 65020 |
| `aws_vpn_gateway_attachment` | n/a | Binds VGW to VPC |
| `aws_customer_gateway` | `ccl-vpns2s-cgw-azure` | Represents the Azure VPN GW; IP = Azure public IP, ASN = 65010 |
| `aws_vpn_connection` | `ccl-vpns2s-vpn-azure` | BGP, two tunnels created |
| `random_password` | `tunnel1_psk` | 32-char alphanumeric+`._` PSK for tunnel 1 |
| `aws_security_group` | `ccl-vpns2s-sg-workload` | ICMP ingress from Azure VNet CIDR only; egress all |
| `aws_iam_role` + `aws_iam_instance_profile` | `cross-cloud-labs-vpn-s2s-workload-*` | Grants `AmazonSSMManagedInstanceCore` to the EC2 (IAM names use the long prefix per [`docs/reference-architectures/aws/iam/deployer.md`](../iam/deployer.md)) |
| `aws_instance` | `ccl-vpns2s-workload` | t3.micro AL2023 ping target |

All resources carry the required tags: `owner=zane`, `project=cross-cloud-labs`, `lab=vpn-site-to-site`, `managed_by=terraform` — applied via the AWS provider's `default_tags` block.

## 4. Networking

- **VPC**: 10.20.0.0/16. DNS support and DNS hostnames both on (required for SSM).
- **Subnets**: both in `us-east-1a` (single-AZ — this is a learning lab, not an HA exercise).
  - Public 10.20.0.0/24: 0.0.0.0/0 → IGW. No instances in v1.
  - Workload 10.20.1.0/24: 0.0.0.0/0 → IGW (for SSM egress); Azure CIDR (10.10.0.0/16) → VGW, learned via BGP route propagation.
- **VGW**: `amazon_side_asn = 65020`. Attached via the standalone `aws_vpn_gateway_attachment` resource.
- **Customer Gateway**: `bgp_asn = 65010`, `ip_address = <azure_gw_public_ip>` (paste from Azure round-1 output), `type = ipsec.1`.
- **VPN Connection**: `static_routes_only = false` (BGP). Both tunnels are created. Tunnel 1's PSK is pinned via `random_password`; tunnel 2's is AWS-default and unused in v1.
- **Tunnel 1 inside CIDR**: `169.254.21.0/30` (locked cross-cloud param — AWS VGW = `.1`, Azure VPN GW = `.2`). Pinned on `aws_vpn_connection` via `tunnel1_inside_cidr` so the BGP peer addresses are deterministic and match what the Azure side configures. Note: changing this attribute is a force-new — Terraform will replace the VPN connection, which generates new tunnel public IPs.
- **Tunnel 2 inside CIDR**: left to AWS default (HA future-work).
- **Route propagation**: enabled only on the workload route table.
- **Exposure**: workload SG ingress is exclusively ICMP from `var.azure_vnet_cidr`. Egress is unrestricted (required for SSM and ICMP back to Azure). The EC2 has a public IPv4 for SSM bootstrap; SG denies all public ingress.

## 5. Identity

- **EC2 instance role** `cross-cloud-labs-vpn-s2s-workload-role` (instance profile of the same stem): trust policy = EC2 service. One managed-policy attachment: `AmazonSSMManagedInstanceCore` (read SSM messages, write instance inventory, no PassRole). The full `cross-cloud-labs-` prefix is required — see Gotcha 7.
- **No IAM users** are created. Long-lived access keys are forbidden by the project rules — local Terraform auth uses the deploy-user creds in `.env`.
- **No KMS** customer-managed keys; EBS root volume uses the default AWS-managed key.

## 6. Cost

| Item | Rate | Monthly est. (always-on) | Lab cost (nightly teardown) |
|---|---|---|---|
| VGW | $0 | $0 | $0 |
| VPN Connection (per tunnel-pair) | $0.05/hr | ~$36 | cents |
| t3.micro | $0.0104/hr | ~$7.50 | cents (free-tier eligible) |
| Public IPv4 on EC2 | $0.005/hr | ~$3.65 | cents |
| EBS gp3 8GB | ~$0.001/hr | ~$0.80 | cents |
| Data out over VPN | $0.09/GB | trivial for ICMP | trivial |

**Dominant driver: the VPN Connection at $0.05/hr — that's the line item to kill at end of day.** A teardown-and-re-apply cycle takes ~5 minutes; the VGW comes up quickly but the IPSec tunnels can take 1–3 minutes to negotiate after both sides exist.

## 7. Teardown

`./destroy.sh` in the lab dir wraps `terraform destroy -auto-approve`. Order is handled by Terraform's dependency graph:

1. EC2 → SG → IAM role/profile.
2. VPN Connection → Customer Gateway.
3. VPN Gateway Attachment → VGW.
4. Route propagation → Route Tables → Subnets → IGW → VPC.

No special flags required (no S3 buckets with `force_destroy`, no Azure-style soft-delete). If `terraform destroy` hangs on the VPN Connection, it's typically because the Azure side's Connection still has it as a peer — destroy the Azure side's Connection first, or just let it time out (a few minutes).

The repo-root `teardown-all.sh` currently only walks `labs/` (legacy layout) — pending an update to walk `aws/labs/` and `azure/labs/`. Until then, run the per-lab `destroy.sh` directly.

## 8. Cross-cloud notes

| AWS | Azure equivalent |
|---|---|
| VPC | VNet |
| Subnet | Subnet |
| Internet Gateway | (implicit in VNet egress) |
| Route Table | Route Table (UDR) |
| Security Group | Network Security Group |
| Virtual Private Gateway (VGW) | VPN Gateway (VpnGw1+) |
| Customer Gateway | Local Network Gateway |
| VPN Connection | Connection |
| Route propagation on a Route Table | "Propagate gateway routes" toggle / BGP learning |
| Tunnel public IPs (auto-assigned per VPN Connection) | VPN Gateway public IP (one or two with active-active) |

For multi-VPC AWS-side hubs, the Azure analogue of TGW is the **Virtual WAN hub** (lab #2).

## 9. Gotchas

- **PSK character set**: AWS PSK must match `[A-Za-z0-9._]{8,64}` and cannot start with `0`. `random_password` here is configured with `override_special = "._"` and `min_*` constraints to satisfy this. Hand-rolling outside that set will fail validation.
- **BGP ASN reservations**: AWS reserves several public ASNs (7224, 9059, 17493, 22697, etc.) and rejects them on the VGW. Stick to private ASNs (64512–65534, 4200000000–4294967294). 65010/65020 are safe.
- **Asymmetric tunnels**: Both AWS tunnels are always created. If the Azure side connects only to tunnel 1, tunnel 2's status will sit at `DOWN` indefinitely — that's not an error, it's just unused HA capacity.
- **Public IP on a "private" subnet**: the workload subnet has a 0/0 route to IGW so SSM works without paying for VPC endpoints or NAT. The subnet *name* says workload, but it is technically internet-attached. SG ingress is the only thing protecting the EC2.
- **DPD timeouts during testing**: AWS defaults Dead Peer Detection timeout to 30s with `clear` action — if you idle the tunnel for >30s with no traffic and no BGP keepalives, AWS will tear the SA down. With BGP enabled (our setup), keepalives prevent this in practice.
- **`aws_vpn_gateway_attachment` vs. inline `vpc_id`**: we use the standalone attachment resource per the lab spec. Either works, but mixing both leads to drift — pick one and stay consistent.
- **Single AZ**: the lab is single-AZ. A real deployment would put workload subnets in ≥2 AZs; the VPN tunnels themselves are independent of AZ since they terminate on the VGW.
- **IAM names must use the long `cross-cloud-labs-` prefix** (not the short `ccl-vpns2s-` used elsewhere in the lab). The deployer's inline policy (`docs/reference-architectures/aws/iam/deployer.md`) only authorises IAM actions against ARNs matching `cross-cloud-labs-*` — anything else fails with `AccessDenied: iam:CreateRole`. We split the prefixes on purpose: short prefix for VPC/SG/EC2 to keep names readable, full prefix for IAM to satisfy the policy. Found the hard way on first apply (2026-05-03).
- **Apply takes ~6 minutes** because `aws_vpn_gateway` (~30s), `aws_vpn_gateway_attachment` (~30s), and `aws_vpn_connection` (~4 min) are all serially slow. Plan accordingly when iterating.

## 10. Related Terraform

- Lab: [`aws/labs/vpn-site-to-site/`](../../../../aws/labs/vpn-site-to-site/) — `main.tf`, `variables.tf`, `outputs.tf`, `destroy.sh`.
- Cross-cloud doc: [`docs/reference-architectures/cross-cloud/vpn-site-to-site/`](../../cross-cloud/vpn-site-to-site/) (canonical for the dual-sided topology; owned by the Azure session).
- Azure side: [`azure/labs/vpn-site-to-site/`](../../../../azure/labs/vpn-site-to-site/).
