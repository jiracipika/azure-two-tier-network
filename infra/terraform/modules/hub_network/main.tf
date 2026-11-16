# Two-tier hub network: VNet with web/app/bastion subnets, per-subnet NSGs and
# a NAT gateway for controlled outbound access.
#
# Security invariants (do not relax without a documented security review):
# - the app subnet accepts traffic ONLY from the web subnet (API) and from the
#   bastion subnet (SSH); it is never reachable from the Internet;
# - the web subnet accepts client HTTP from the Internet and health probes from
#   AzureLoadBalancer as two SEPARATE rules (a health-probe rule is not a
#   client access rule);
# - no NSG rule anywhere allows SSH/RDP inbound from the Internet;
# - VM subnets disable default outbound access; egress goes through the NAT
#   gateway instead of implicit public IPs.

locals {
  # Subnet plan carved out of the VNet address space. Kept as explicit locals
  # so NSG rules and subnet definitions visibly share the same prefixes.
  web_subnet_prefix     = cidrsubnet(var.address_space[0], 8, 1)     # 10.10.1.0/24
  app_subnet_prefix     = cidrsubnet(var.address_space[0], 8, 2)     # 10.10.2.0/24
  bastion_subnet_prefix = cidrsubnet(var.address_space[0], 10, 1000) # 10.10.250.0/26
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.web_subnet_prefix]
  # Outbound egress flows through the NAT gateway, not implicit outbound IPs.
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.app_subnet_prefix]
  # Private tier: no direct outbound either without the NAT gateway.
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # fixed name required by Azure Bastion
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.bastion_subnet_prefix]
}

# --- NAT gateway: single controlled egress path for VM subnets --------------

resource "azurerm_nat_gateway" "this" {
  name                = var.nat_gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "nat" {
  name                = "${var.nat_gateway_name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "web" {
  subnet_id      = azurerm_subnet.web.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

resource "azurerm_subnet_nat_gateway_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

# --- NSG shells (rules are separate azurerm_network_security_rule resources,
# --- the azurerm 4.x pattern) and subnet associations ------------------------

resource "azurerm_network_security_group" "web" {
  name                = "${var.vnet_name}-nsg-web"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_group" "app" {
  name                = "${var.vnet_name}-nsg-app"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_group" "bastion" {
  name                = "${var.vnet_name}-nsg-bastion"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}
