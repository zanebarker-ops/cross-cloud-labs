# Cross-cloud reference architecture — Site-to-Site IPSec VPN (Azure ↔ AWS)

**Status:** v1, BGP-routed, single-tunnel.
**Lab paths:** `azure/labs/vpn-site-to-site/` · `aws/labs/vpn-site-to-site/`

This document is the source of truth for the lab. If Terraform on either side disagrees with this doc, the doc wins or the doc is updated deliberately.

## 1. Purpose

Establish a working IPSec site-to-site VPN between an Azure VNet and an AWS VPC, using BGP for dynamic route exchange, so that workload VMs in each cloud can `ping` each other across the tunnel.

This is the foundational connectivity lab. Subsequent labs (Azure Virtual WAN, AWS Transit Gateway) will build on the patterns established here.

## 2. Topology

```
                              ┌────────────────────────────────────────┐
                              │            Public Internet             │
                              │                                        │
                              │   IPSec/IKEv2 tunnel (BGP-routed)      │
                              └────────────┬───────────────┬───────────┘
                                           │               │
                ┌──────────────────────────┘               └──────────────────────────┐
                │                                                                     │
   ┌────────────▼─────────────┐                                       ┌───────────────▼──────────┐
   │   Azure  (eastus)        │                                       │   AWS  (us-east-1)       │
   │   VNet  10.10.0.0/16     │                                       │   VPC  10.20.0.0/16      │
   │                          │                                       │                          │
   │   GatewaySubnet          │                                       │   public subnet          │
   │   10.10.255.0/27         │                                       │   10.20.0.0/24           │
   │   ┌────────────────┐     │                                       │   ┌────────────────┐     │
   │   │ VPN Gateway    │◄────┼───── BGP peering (ASN 65010↔65020) ───┼──►│ Virtual Private│     │
   │   │  VpnGw1        │     │                                       │   │ Gateway (VGW)  │     │
   │   │  ASN 65010     │     │                                       │   │  ASN 65020     │     │
   │   │  pub IP        │     │                                       │   │  attached to   │     │
   │   └────────┬───────┘     │                                       │   │  VPC           │     │
   │            │ peers with  │                                       │   └────────┬───────┘     │
   │   ┌────────▼───────┐     │                                       │            │ propagates  │
   │   │ Local Network  │     │                                       │   ┌────────▼───────┐     │
   │   │ Gateway        │     │                                       │   │ Customer       │     │
   │   │  target =      │     │                                       │   │ Gateway (CGW)  │     │
   │   │  AWS tunnel1   │     │                                       │   │  target =      │     │
   │   │  ASN 65020     │     │                                       │   │  Azure GW IP   │     │
   │   └────────────────┘     │                                       │   │  ASN 65010     │     │
   │                          │                                       │   └────────────────┘     │
   │   workload subnet        │                                       │   workload subnet        │
   │   10.10.1.0/24           │                                       │   10.20.1.0/24           │
   │   ┌────────────────┐     │                                       │   ┌────────────────┐     │
   │   │ VM (B1s)       │ ◄───┼─────────  ICMP allowed  ──────────────┼─► │ EC2 (t3.micro) │     │
   │   │ Ubuntu 22.04   │     │                                       │   │ Amazon Linux   │     │
   │   └────────────────┘     │                                       │   └────────────────┘     │
   └──────────────────────────┘                                       └──────────────────────────┘
```

## 3. Components

### Azure side (`azure/labs/vpn-site-to-site/`)

| Resource | Type | Purpose |
|---|---|---|
| `rg-cross-cloud-labs-vpn-eastus` | `azurerm_resource_group` | Container for all lab resources |
| `vnet-eastus` | `azurerm_virtual_network` | 10.10.0.0/16 |
| `GatewaySubnet` | `azurerm_subnet` | 10.10.255.0/27 — required name, holds VPN GW |
| `snet-workload` | `azurerm_subnet` | 10.10.1.0/24 — holds the test VM |
| `pip-vpngw` | `azurerm_public_ip` | Static, Standard SKU (required by VpnGw1) |
| `vng-eastus` | `azurerm_virtual_network_gateway` | VpnGw1 SKU, route-based, BGP enabled, ASN 65010 |
| `lng-aws-tunnel1` | `azurerm_local_network_gateway` | Represents AWS tunnel1 endpoint + AWS VGW BGP ASN |
| `cn-azure-aws` | `azurerm_virtual_network_gateway_connection` | IPSec Connection (BGP, PSK) |
| `nsg-workload` | `azurerm_network_security_group` | Permits ICMP from 10.20.0.0/16 only |
| `vm-azure-workload` | `azurerm_linux_virtual_machine` | B1s Ubuntu 22.04, no public IP |

### AWS side (`aws/labs/vpn-site-to-site/`)

| Resource | Type | Purpose |
|---|---|---|
| `vpc-cross-cloud-labs` | `aws_vpc` | 10.20.0.0/16 |
| `subnet-public` | `aws_subnet` | 10.20.0.0/24 |
| `subnet-workload` | `aws_subnet` | 10.20.1.0/24 |
| `igw` | `aws_internet_gateway` | Public egress for the public subnet |
| `vgw` | `aws_vpn_gateway` | ASN 65020, attached to VPC |
| `cgw-azure` | `aws_customer_gateway` | Target Azure VPN GW public IP, BGP ASN 65010 |
| `vpn` | `aws_vpn_connection` | BGP, `static_routes_only = false`, 2 tunnels (only tunnel 1 used in v1) |
| `rt-workload` | `aws_route_table` | Route propagation enabled from VGW |
| `sg-workload` | `aws_security_group` | Permits ICMP from 10.10.0.0/16 only |
| `ec2-workload` | `aws_instance` | t3.micro Amazon Linux 2023, no public IP |

## 4. Networking

### IP plan

| Range | Owner | Purpose |
|---|---|---|
| `10.10.0.0/16` | Azure | VNet |
| `10.10.255.0/27` | Azure | GatewaySubnet (mandatory naming) |
| `10.10.1.0/24` | Azure | Workload subnet |
| `10.20.0.0/16` | AWS | VPC |
| `10.20.0.0/24` | AWS | Public subnet (IGW egress) |
| `10.20.1.0/24` | AWS | Workload subnet |

### BGP

| Side | ASN | Notes |
|---|---|---|
| Azure VPN GW | 65010 | Configured on `azurerm_virtual_network_gateway.bgp_settings` |
| AWS VGW | 65020 | Configured on `aws_vpn_gateway.amazon_side_asn` |

Each side advertises its own VNet/VPC CIDR; both sides install the remote prefix via BGP.

### Tunnel inside CIDR (locked — both sides must match)

| | Value |
|---|---|
| Tunnel 1 inside /30 | `169.254.21.0/30` |
| AWS-side BGP peering address | `169.254.21.1` |
| Azure-side BGP peering address | `169.254.21.2` |

These are pinned (rather than letting AWS auto-pick) because Azure's `azurerm_local_network_gateway.bgp_settings.bgp_peering_address` requires a known remote APIPA at apply time, and Azure VPN GW must declare its own APIPA via `bgp_settings.peering_addresses[].apipa_addresses`.

**AWS side:** set `aws_vpn_connection.tunnel1_inside_cidr = "169.254.21.0/30"`. AWS will assign `169.254.21.1` to its tunnel endpoint; Azure binds `169.254.21.2`.

### Tunnels

AWS Site-to-Site VPN provisions two tunnels by default (HA design). v1 of this lab terminates **only tunnel 1** on the Azure side. Tunnel 2 is documented as a future-work HA enhancement that requires Azure VPN GW in active-active mode.

## 5. Identity

### Azure

- Terraform runs as a service principal stored in `.env` (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`). Recommended scope: `Contributor` on the lab subscription. No managed identities or RBAC role assignments created by this lab.

### AWS

- Terraform runs as an IAM user with programmatic access (keys in `.env`). Recommended scope: a custom policy granting only `ec2:*`, `iam:PassRole` for EC2 instance profiles (none used in v1), and `vpc:*` semantics covered by `ec2:*`. No IAM roles, users, or policies are created by this lab.

## 6. Cost

### Steady-state (per hour, while running)

| Item | Cloud | Hourly | Notes |
|---|---|---|---|
| VPN Gateway VpnGw1 | Azure | ~$0.19 | The dominant cost on the Azure side |
| Standard public IP | Azure | ~$0.005 | One per VPN GW; required by VpnGw1 |
| B1s VM | Azure | ~$0.0104 | Ubuntu image, no extra license |
| Standard managed disk (Premium SSD 30GB) | Azure | ~$0.006 | OS disk |
| VPN Connection | AWS | ~$0.05 | Charged regardless of tunnel state |
| t3.micro | AWS | ~$0.0104 | May be free-tier covered |
| Public IPv4 (any unattached or attached) | AWS | ~$0.005 each | Watch out for stranded EIPs |
| Data transfer over VPN | AWS | $0.09 / GB out | Negligible for ping/SSH |

### Daily total (running 8 hours, then teardown)

Roughly **$2.10/day** if you keep it up all 8 hours of a workday. With same-day teardown, well under $1/day.

### If left running 24h

Roughly **$6.50/day** (~$200/month). This is why we tear down nightly.

## 7. Teardown

Each side's `destroy.sh` runs `terraform destroy -auto-approve` for that root. Walk both via `./teardown-all.sh` from repo root (script will be updated to recurse `azure/labs/*` and `aws/labs/*`).

### Known teardown gotchas

- **Azure VPN GW** takes 10–20 minutes to delete. Expect a long destroy.
- **Azure Public IP** cannot delete while VPN GW holds it — Terraform handles ordering.
- **AWS VPN Connection** must delete before VGW can detach. Terraform handles this.
- **AWS VGW detach** can hang if a VPN connection or route propagation lingers. Both are managed by TF.
- **Stranded EIPs / public IPs** are the most common forgotten cost. Both sides intentionally avoid creating any (workload VMs are private-only).

## 8. Cross-cloud notes

| Azure concept | AWS equivalent | Same in this lab? |
|---|---|---|
| VNet | VPC | yes |
| GatewaySubnet | (no equivalent — VGW attaches to VPC, not subnet) | n/a |
| VPN Gateway (VirtualNetworkGateway) | Virtual Private Gateway (VGW) | yes |
| Local Network Gateway | Customer Gateway | yes |
| Connection (`virtual_network_gateway_connection`) | VPN Connection (`aws_vpn_connection`) | yes |
| Route table (per-subnet association) | Route table (per-subnet association) + route propagation | similar |
| NSG | Security Group + NACL | NSG ≈ SG; no NACL used |

## 9. Gotchas

- **Pre-shared key:** AWS auto-generates the PSK on the VPN connection. Azure must consume the *exact* same PSK on the Connection resource. Manual paste from AWS outputs into Azure tfvars (gitignored) is the workflow.
- **BGP ASN clashes:** Azure default ASN is 65515. We deliberately picked 65010/65020 so neither side accidentally collides with an Azure default.
- **Encryption domains:** with BGP and route-based VPNs on both sides, the IKE/IPSec SA negotiates `0.0.0.0/0 ↔ 0.0.0.0/0` (any-any). Routing decides what actually traverses.
- **MTU:** AWS VPN Connection enforces MSS clamping by default. If you see 1500-byte pings work but TCP stalls, suspect MSS — verify clamping on the AWS side.
- **Active-standby vs active-active:** Azure VpnGw1 in active-standby mode has one public IP and one BGP peer. Active-active would need two public IPs and two LocalNetworkGateways to use both AWS tunnels. v1 keeps it simple; HA is future work.
- **GatewaySubnet name is mandatory:** it must be exactly `GatewaySubnet`. No prefix.
- **`force_destroy` on storage:** the Azure VM uses ephemeral OS disk where possible to avoid orphaned managed disks on destroy. If non-ephemeral, the disk's `delete_option = "Delete"` must be set on the OS disk.
- **AWS public IPv4 cost (since 2024):** every EIP, every default-assigned EC2 public IP, even when attached, is now $0.005/hr. The workload EC2 deliberately has no public IP for this reason.

## 10. Validation

After both sides apply (phase 3 complete):

1. **Azure → AWS tunnel state:** Azure portal → VPN Gateway → Connections → status should be `Connected`. Or:
   ```
   az network vpn-connection show -g rg-cross-cloud-labs-vpn-eastus -n cn-azure-aws --query connectionStatus
   ```
2. **AWS tunnel state:**
   ```
   aws ec2 describe-vpn-connections --query 'VpnConnections[].VgwTelemetry[].Status'
   ```
   Tunnel 1 should be `UP`. Tunnel 2 will be `DOWN` (expected — not configured on Azure side in v1).
3. **BGP:** routes for `10.20.0.0/16` should appear in Azure VPN GW; `10.10.0.0/16` should appear in AWS workload route table.
4. **Cross-cloud ping:** SSH into either workload VM (via Bastion / SSM Session Manager — not via public IP), then `ping <other-side-private-ip>`.

## 11. Related Terraform

- Azure: `azure/labs/vpn-site-to-site/`
- AWS: `aws/labs/vpn-site-to-site/`
- Azure-side resource ref doc: `docs/reference-architectures/azure/networking/vpn-gateway.md`
- AWS-side resource ref doc: `docs/reference-architectures/aws/networking/vpn-site-to-site.md` (owned by AWS session)
