# Root module. All Azure resources are gated behind deploy_enabled (default
# false): with the default variables `terraform plan` proposes zero changes
# outside the placeholder provider configuration.
locals {
  project = "azure-two-tier-network"
  tags    = merge(var.tags, { project = local.project })
}

resource "azurerm_resource_group" "this" {
  count    = var.deploy_enabled ? 1 : 0
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

module "hub_network" {
  count               = var.deploy_enabled ? 1 : 0
  source              = "./modules/hub_network"
  resource_group_name = one(azurerm_resource_group.this[*].name)
  location            = var.location
  vnet_name           = "vnet-two-tier"
  address_space       = var.vnet_address_space
  tags                = local.tags
}

module "bastion" {
  count               = var.deploy_enabled ? 1 : 0
  source              = "./modules/bastion"
  resource_group_name = one(azurerm_resource_group.this[*].name)
  location            = var.location
  bastion_subnet_id   = one(module.hub_network[*].bastion_subnet_id)
  bastion_sku         = var.bastion_sku
  tags                = local.tags
}

module "web_tier" {
  count                = var.deploy_enabled ? 1 : 0
  source               = "./modules/web_tier"
  resource_group_name  = one(azurerm_resource_group.this[*].name)
  location             = var.location
  web_subnet_id        = one(module.hub_network[*].web_subnet_id)
  web_vm_count         = var.web_vm_count
  vm_size              = var.vm_size
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key
  tags                 = local.tags
}

module "app_tier" {
  count                = var.deploy_enabled ? 1 : 0
  source               = "./modules/app_tier"
  resource_group_name  = one(azurerm_resource_group.this[*].name)
  location             = var.location
  app_subnet_id        = one(module.hub_network[*].app_subnet_id)
  vm_size              = var.vm_size
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key
  tags                 = local.tags
}
