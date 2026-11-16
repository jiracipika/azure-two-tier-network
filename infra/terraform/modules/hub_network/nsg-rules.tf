# Explicit NSG rule matrix. Rules are standalone azurerm_network_security_rule
# resources (azurerm 4.x pattern); lowest priority number wins, unmatched
# inbound traffic is denied by the platform default rule.

# --- nsg-web: public web tier -----------------------------------------------
# Client access rule: the ONLY path for end-user traffic into the workload.
resource "azurerm_network_security_rule" "web_in_http" {
  name                        = "Allow-HTTP-From-Internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = local.web_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.web.name
}

# Health probe rule. Distinct from the client rule above: load-balancer probes
# originate from the AzureLoadBalancer service tag (168.63.129.16) and MUST be
# allowed separately — a health-probe rule does NOT authorize client traffic,
# and client rules do NOT keep probes healthy.
resource "azurerm_network_security_rule" "web_in_probe" {
  name                        = "Allow-HealthProbe-From-AzureLB"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = local.web_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.web.name
}

# Trusted management path: SSH to web VMs ONLY from the bastion subnet.
resource "azurerm_network_security_rule" "web_in_ssh_bastion" {
  name                        = "Allow-SSH-From-Bastion"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = local.bastion_subnet_prefix
  destination_address_prefix  = local.web_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.web.name
}

# --- nsg-app: private app tier ----------------------------------------------
# API traffic ONLY from the web subnet. No Internet source exists in this NSG.
resource "azurerm_network_security_rule" "app_in_api" {
  name                        = "Allow-API-From-Web"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = local.web_subnet_prefix
  destination_address_prefix  = local.app_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.app.name
}

# Trusted management path: SSH to the API VM ONLY from the bastion subnet.
resource "azurerm_network_security_rule" "app_in_ssh_bastion" {
  name                        = "Allow-SSH-From-Bastion"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = local.bastion_subnet_prefix
  destination_address_prefix  = local.app_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.app.name
}

# --- nsg-bastion: rule set required by Azure Bastion ------------------------
# Reference: Azure Bastion NSG requirements (data-plane + control-plane ports).
resource "azurerm_network_security_rule" "bastion_in_https" {
  name                        = "Allow-HTTPS-From-Internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = local.bastion_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_in_gateway_manager" {
  name                        = "Allow-HTTPS-From-GatewayManager"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = local.bastion_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_in_lb" {
  name                        = "Allow-HTTPS-From-AzureLoadBalancer"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = local.bastion_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_in_host_communication" {
  name                        = "Allow-BastionHostCommunication-In"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["8080", "5701"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = local.bastion_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_out_ssh_rdp" {
  name                        = "Allow-SSH-RDP-To-VNet"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389"]
  source_address_prefix       = local.bastion_subnet_prefix
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_out_host_communication" {
  name                        = "Allow-BastionHostCommunication-Out"
  priority                    = 210
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["8080", "5701"]
  source_address_prefix       = local.bastion_subnet_prefix
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_out_azure_https" {
  name                        = "Allow-HTTPS-To-AzureCloud"
  priority                    = 220
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = local.bastion_subnet_prefix
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion_out_http" {
  name                        = "Allow-HTTP-To-Internet-SessionValidation"
  priority                    = 230
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = local.bastion_subnet_prefix
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}
