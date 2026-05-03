resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-eastus"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.workload_subnet_prefix]
}

resource "azurerm_public_ip" "vpngw" {
  name                = "pip-vpngw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "this" {
  name                = "vng-eastus"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = var.vpn_gateway_sku

  active_active = false
  enable_bgp    = true

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpngw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  bgp_settings {
    asn = var.azure_bgp_asn

    peering_addresses {
      ip_configuration_name = "vnetGatewayConfig"
      apipa_addresses       = [var.azure_bgp_peering_address]
    }
  }

  tags = var.tags
}

# ---------- Phase-3 resources: created only when AWS outputs are pasted in ----------

resource "azurerm_local_network_gateway" "aws_tunnel1" {
  count = var.create_connection ? 1 : 0

  name                = "lng-aws-tunnel1"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  gateway_address = var.aws_tunnel1_address
  address_space   = [var.aws_vpc_cidr]

  bgp_settings {
    asn                 = var.aws_vgw_asn
    bgp_peering_address = var.aws_bgp_peering_address
  }

  tags = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "aws_tunnel1" {
  count = var.create_connection ? 1 : 0

  name                = "cn-azure-aws"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws_tunnel1[0].id

  shared_key = var.aws_tunnel1_psk
  enable_bgp = true

  tags = var.tags
}

# ---------- Workload VM ----------

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-workload"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "icmp_from_aws" {
  name                        = "allow-icmp-from-aws"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.workload.name

  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Icmp"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = var.aws_vpc_cidr
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "ssh_from_vnet" {
  name                        = "allow-ssh-from-vnet"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.workload.name

  priority                   = 110
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = var.vnet_address_space
  destination_address_prefix = "*"
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

resource "azurerm_network_interface" "workload" {
  name                = "nic-azure-workload"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "workload" {
  name                = "vm-azure-workload"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = "Standard_B1s"
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.workload.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = var.tags
}

