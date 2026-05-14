variable "location" {
  description = "Azure region for the lab. eastus2 paired with AWS us-east-1 — eastus2 has reliable small-VM SKU capacity (eastus is heavily restricted as of 2026-05)."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Resource group name for all lab resources."
  type        = string
  default     = "rg-cross-cloud-labs-vpn-eastus2"
}

variable "vnet_address_space" {
  description = "Azure VNet CIDR. Locked at the cross-cloud level."
  type        = string
  default     = "10.10.0.0/16"
}

variable "gateway_subnet_prefix" {
  description = "GatewaySubnet CIDR (must be named exactly 'GatewaySubnet')."
  type        = string
  default     = "10.10.255.0/27"
}

variable "workload_subnet_prefix" {
  description = "Workload subnet CIDR for the test VM."
  type        = string
  default     = "10.10.1.0/24"
}

variable "azure_bgp_asn" {
  description = "Azure VPN Gateway BGP ASN. Locked."
  type        = number
  default     = 65010
}

variable "vpn_gateway_sku" {
  description = "Azure VPN Gateway SKU. Must be an AZ SKU — Microsoft retired the non-AZ VpnGw1-5 SKUs (NonAzSkusNotAllowedForVPNGateway). VpnGw1AZ is the cheapest BGP-capable option."
  type        = string
  default     = "VpnGw1AZ"
}

variable "admin_username" {
  description = "Workload VM admin username."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "Workload VM admin SSH public key (paste full ssh-rsa or ssh-ed25519 line)."
  type        = string
}

# ----- Phase-3 inputs (populate from AWS session outputs after their apply) -----
# Leave blank on the round-1 apply. Phase 1 only creates the VPN GW + public IP.
# Round-2 apply (after AWS apply) populates these and creates the LNG + Connection.

variable "aws_tunnel1_address" {
  description = "Public IP of AWS VPN tunnel 1 (from AWS terraform output). Leave empty on phase-1 apply."
  type        = string
  default     = ""
}

variable "aws_tunnel1_psk" {
  description = "Pre-shared key for AWS VPN tunnel 1 (from AWS terraform output, sensitive). Leave empty on phase-1 apply."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_vgw_asn" {
  description = "AWS VGW BGP ASN (from AWS terraform output). Locked at 65020."
  type        = number
  default     = 65020
}

variable "aws_vpc_cidr" {
  description = "AWS VPC CIDR (from AWS terraform output). Locked at 10.20.0.0/16."
  type        = string
  default     = "10.20.0.0/16"
}

variable "tunnel1_inside_cidr" {
  description = "Inside-tunnel /30 APIPA range for tunnel 1. Locked across both clouds. AWS gets .1, Azure gets .2."
  type        = string
  default     = "169.254.21.0/30"
}

variable "aws_bgp_peering_address" {
  description = "AWS-side BGP peering APIPA address (the .1 of tunnel1_inside_cidr)."
  type        = string
  default     = "169.254.21.1"
}

variable "azure_bgp_peering_address" {
  description = "Azure-side BGP peering APIPA address (the .2 of tunnel1_inside_cidr)."
  type        = string
  default     = "169.254.21.2"
}

variable "create_connection" {
  description = "Set to true on the round-2 apply to create LocalNetworkGateway + Connection. Leave false on round-1 apply."
  type        = bool
  default     = false
}

# ----- Tags -----

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    owner      = "zane"
    project    = "cross-cloud-labs"
    lab        = "vpn-site-to-site"
    managed_by = "terraform"
  }
}
