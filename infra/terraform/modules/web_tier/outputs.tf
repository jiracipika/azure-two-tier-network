output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb.ip_address
}

output "web_vm_private_ips" {
  value = azurerm_network_interface.web[*].private_ip_address
}
