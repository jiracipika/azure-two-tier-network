# Azure Bastion: the ONLY permitted management entry point. No public SSH/RDP
# exists on workload VMs; administrators reach them through this host over TLS.
resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  name                = "bastion-two-tier"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.bastion_sku
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
