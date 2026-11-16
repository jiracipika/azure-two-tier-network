output "app_vm_private_ip" {
  value = azurerm_network_interface.app.private_ip_address
}

output "app_port" {
  value = var.app_port
}
