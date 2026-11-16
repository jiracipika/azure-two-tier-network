output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "web_subnet_id" {
  value = azurerm_subnet.web.id
}

output "app_subnet_id" {
  value = azurerm_subnet.app.id
}

output "bastion_subnet_id" {
  value = azurerm_subnet.bastion.id
}

output "web_subnet_prefix" {
  value = local.web_subnet_prefix
}

output "app_subnet_prefix" {
  value = local.app_subnet_prefix
}

output "bastion_subnet_prefix" {
  value = local.bastion_subnet_prefix
}
