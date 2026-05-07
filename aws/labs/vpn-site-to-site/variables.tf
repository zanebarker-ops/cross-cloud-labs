# ---- AWS region / placement -------------------------------------------------

variable "aws_region" {
  description = "AWS region for the lab. Locked to us-east-1 by the cross-cloud lab spec."
  type        = string
  default     = "us-east-1"
}

variable "aws_az" {
  description = "Availability zone for both subnets."
  type        = string
  default     = "us-east-1a"
}

# ---- AWS network -----------------------------------------------------------

variable "aws_vpc_cidr" {
  description = "CIDR for the AWS VPC. Locked to 10.20.0.0/16."
  type        = string
  default     = "10.20.0.0/16"
}

variable "aws_public_subnet_cidr" {
  description = "Public subnet CIDR (reserved for future bastion/NAT — not used by the workload in v1)."
  type        = string
  default     = "10.20.0.0/24"
}

variable "aws_workload_subnet_cidr" {
  description = "Workload subnet CIDR. Holds the t3.micro test instance and receives BGP-propagated Azure routes."
  type        = string
  default     = "10.20.1.0/24"
}

variable "aws_vgw_asn" {
  description = "BGP ASN for the AWS Virtual Private Gateway. Locked to 65020."
  type        = number
  default     = 65020
}

# ---- Inputs from Azure (round-1 outputs) -----------------------------------

variable "azure_gw_public_ip" {
  description = "Public IP of the Azure VPN Gateway. Provided by the Azure side after its round-1 apply."
  type        = string
}

variable "azure_bgp_asn" {
  description = "BGP ASN advertised by the Azure VPN Gateway. Locked to 65010."
  type        = number
  default     = 65010
}

variable "azure_vnet_cidr" {
  description = "Azure VNet CIDR. Used to scope the workload SG ICMP ingress rule."
  type        = string
  default     = "10.10.0.0/16"
}
