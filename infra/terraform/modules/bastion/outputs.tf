output "bastion_host_id" {
  value = azurerm_bastion_host.this.id
}

output "dns_name" {
  description = "Bastion TLS endpoint hostname used by browser-based SSH sessions."
  value       = azurerm_bastion_host.this.dns_name
}
