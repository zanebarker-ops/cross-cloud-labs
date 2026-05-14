output "aws_tunnel1_address" {
  description = "Public IP of AWS VPN tunnel 1. Paste into Azure Local Network Gateway target."
  value       = aws_vpn_connection.azure.tunnel1_address
}

output "aws_tunnel1_psk" {
  description = "Pre-shared key for AWS VPN tunnel 1. Paste into Azure Connection shared_key. Sensitive — read with `terraform output -raw aws_tunnel1_psk`."
  value       = aws_vpn_connection.azure.tunnel1_preshared_key
  sensitive   = true
}

output "aws_vgw_asn" {
  description = "AWS-side BGP ASN advertised over the tunnel. Used as the Azure Local Network Gateway BGP ASN."
  value       = aws_vpn_gateway.this.amazon_side_asn
}

output "aws_vpc_cidr" {
  description = "AWS VPC CIDR. Used as the Azure Local Network Gateway address space."
  value       = aws_vpc.this.cidr_block
}

output "aws_workload_private_ip" {
  description = "Private IP of the AWS workload EC2 instance — ping target from the Azure VM."
  value       = aws_instance.workload.private_ip
}

# ---- Diagnostic / HA-future-work outputs -----------------------------------

output "aws_tunnel2_address" {
  description = "Public IP of AWS VPN tunnel 2. Not consumed by Azure in v1; documented for HA follow-up."
  value       = aws_vpn_connection.azure.tunnel2_address
}

output "aws_workload_instance_id" {
  description = "EC2 instance ID — connect via `aws ssm start-session --target <id>`."
  value       = aws_instance.workload.id
}
