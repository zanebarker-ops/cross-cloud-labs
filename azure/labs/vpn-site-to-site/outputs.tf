output "azure_gw_public_ip" {
  description = "Public IP of the Azure VPN Gateway. Paste this into the AWS lab's terraform.tfvars as `azure_gw_public_ip`."
  value       = azurerm_public_ip.vpngw.ip_address
}

output "azure_bgp_asn" {
  description = "Azure VPN Gateway BGP ASN. Paste into AWS as `azure_bgp_asn`."
  value       = var.azure_bgp_asn
}

output "azure_vnet_cidr" {
  description = "Azure VNet CIDR. Paste into AWS as `azure_vnet_cidr`."
  value       = var.vnet_address_space
}

output "azure_workload_private_ip" {
  description = "Private IP of the Azure workload VM, for cross-cloud ping testing."
  value       = azurerm_network_interface.workload.private_ip_address
}

output "connection_status_command" {
  description = "Az CLI command to check tunnel state after phase 3."
  value       = var.create_connection ? "az network vpn-connection show -g ${azurerm_resource_group.this.name} -n cn-azure-aws --query connectionStatus -o tsv" : "Connection not yet created — run phase-3 apply with create_connection=true"
}
