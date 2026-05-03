# Reference architecture — Azure VPN Gateway (route-based, BGP)

This doc is the source of truth for how we configure the Azure VPN Gateway resource family in this repo. Used by `azure/labs/vpn-site-to-site/` and any future lab that terminates an IPSec tunnel on the Azure side.

## 1. Purpose

Provide a route-based, BGP-capable VPN endpoint inside an Azure VNet so the VNet can establish an IPSec site-to-site tunnel to a partner network (in our case: AWS).

## 2. Diagram

```
┌─────────────────── VNet 10.10.0.0/16 ───────────────────┐
│                                                         │
│   GatewaySubnet 10.10.255.0/27 ─── must be named        │
│   ┌─────────────────────────────┐                       │
│   │ Public IP (Standard, Static)│ ◄── tunnel endpoint   │
│   │            ▲                │                       │
│   │            │                │                       │
│   │  VirtualNetworkGateway      │                       │
│   │   SKU:    VpnGw1            │                       │
│   │   type:   Vpn               │                       │
│   │   vpn:    RouteBased        │                       │
│   │   BGP:    enabled, ASN 65010│                       │
│   └─────────┬───────────────────┘                       │
│             │ peers with                                │
│   ┌─────────▼───────────┐                               │
│   │ LocalNetworkGateway │  represents partner site      │
│   │  IP = remote tunnel │                               │
│   │  ASN = remote ASN   │                               │
│   │  addr = remote CIDR │                               │
│   └─────────┬───────────┘                               │
│             │                                           │
│   ┌─────────▼─────────────────────────┐                 │
│   │ VirtualNetworkGatewayConnection   │                 │
│   │  type = IPsec                     │                 │
│   │  PSK  = (sensitive var)           │                 │
│   │  BGP  = enabled                   │                 │
│   └───────────────────────────────────┘                 │
│                                                         │
│   workload subnet 10.10.1.0/24                          │
│   ┌─────────────────────────────────┐                   │
│   │ workload VMs                    │                   │
│   └─────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

## 3. Components

| Resource | Type | Notes |
|---|---|---|
| Resource group | `azurerm_resource_group` | One per lab. Tagged. |
| VNet | `azurerm_virtual_network` | Address space `10.10.0.0/16`. |
| GatewaySubnet | `azurerm_subnet` | **Name must be exactly `GatewaySubnet`**. /27 minimum, /26+ for active-active. |
| Public IP | `azurerm_public_ip` | `allocation_method = Static`, `sku = Standard`. Required by VpnGw* SKUs. |
| Virtual Network Gateway | `azurerm_virtual_network_gateway` | `type = Vpn`, `vpn_type = RouteBased`, `sku = VpnGw1`, BGP block with `asn = 65010`. |
| Local Network Gateway | `azurerm_local_network_gateway` | One per remote tunnel endpoint. Holds remote tunnel IP, remote ASN, remote address space. |
| Connection | `azurerm_virtual_network_gateway_connection` | `type = IPsec`, links VNG ↔ LNG, carries PSK and `enable_bgp = true`. |

## 4. Networking

### IP plan

- VNet: `10.10.0.0/16`
- GatewaySubnet: `10.10.255.0/27` (last /27 of the VNet, conventional placement)
- Workload subnet: `10.10.1.0/24`

### Routing

- VPN Gateway is route-based, so routes come from BGP (no static `local_network_gateway` address spaces beyond what the LNG declares).
- LNG declares the **remote** address space (`10.20.0.0/16` for AWS) — this is the bootstrap route until BGP is established.
- Workload subnet has the default Azure system route to the Gateway (no UDR required for cross-cloud reach unless overriding).

## 5. Identity

- Terraform service principal needs `Contributor` (or narrower: `Network Contributor` on the resource group + `Reader` on the subscription).
- VM password / SSH key: SSH key auth only. Public key from `var.admin_ssh_public_key`. No password login.
- No managed identity assigned to the workload VM in v1.

## 6. Cost

| Item | Hourly | Monthly (30d) |
|---|---|---|
| VPN Gateway VpnGw1 | ~$0.19 | ~$140 |
| Standard Public IP | ~$0.005 | ~$3.60 |
| B1s VM | ~$0.0104 | ~$7.50 |
| Premium SSD 30GB OS disk | ~$0.006 | ~$5 |
| Outbound data over VPN | $0.087 / GB | usage-based |

**Dominant cost: VPN Gateway.** Daily teardown is essential. Higher SKUs (VpnGw2, VpnGw3) add zero learning value at this stage and ~3–10x cost.

## 7. Teardown

- VPN Gateway delete takes 10–20 minutes. Plan for it.
- Public IP cannot delete while bound to VPN GW — Terraform orders this implicitly via dependency.
- Resource Group destroy as a fallback: works, but Terraform state still references the resources, so use `terraform destroy` first.
- No soft-deleted resources (no Key Vault, no Recovery Vault) so no purge-protection traps.

## 8. Cross-cloud notes

| Azure concept | AWS equivalent |
|---|---|
| Virtual Network Gateway | Virtual Private Gateway (VGW) |
| Local Network Gateway | Customer Gateway |
| Connection | VPN Connection |
| BGP `asn` on VNG | `amazon_side_asn` on `aws_vpn_gateway` |
| Route-based VPN | Default (BGP-capable) on AWS VPN Connection |
| Active-standby vs active-active | AWS always provisions 2 tunnels — Azure must be active-active to terminate both |

## 9. Gotchas

- **`GatewaySubnet` name** is hard-coded by Azure. Spelling it `gatewaysubnet` or `Gateway-Subnet` will fail at apply time.
- **Public IP SKU mismatch:** VpnGw1 requires Standard SKU. Basic SKU public IP will fail validation.
- **BGP block requires generation 2 SKUs** (VpnGw1 and up). Basic SKU has no BGP.
- **Active-active** requires `active_active = true`, two `ip_configuration` blocks, two public IPs, and two LNG/Connection pairs. Out of scope for v1.
- **VNet peering with gateway transit:** if added later, set `use_remote_gateways` carefully — easy to break with circular dependencies.
- **Provisioning time:** VPN GW takes 30–45 minutes to create. First apply is slow; subsequent applies on existing GW are normal.
- **`enable_bgp = true` on Connection** is required even if BGP is enabled on both VNG and LNG — three-way required for actual peering.

## 10. Related Terraform

- `azure/labs/vpn-site-to-site/main.tf`
- Cross-cloud lab doc: `docs/reference-architectures/cross-cloud/vpn-site-to-site/README.md`
