output "status" {
  description = "Guards against mistaking the offline scaffold for a deployment."
  value       = var.deploy_enabled ? "deployment-configured (requires explicit owner approval to apply)" : "offline-scaffold-only"
}

output "load_balancer_public_ip" {
  description = "Public LB IP of the web tier; null unless deploy_enabled is true."
  value       = one(module.web_tier[*].load_balancer_public_ip)
}

output "bastion_dns_name" {
  description = "Bastion TLS endpoint; null unless deploy_enabled is true."
  value       = one(module.bastion[*].dns_name)
}

output "app_vm_private_ip" {
  description = "Private API VM address (unreachable from the Internet); null unless deploy_enabled is true."
  value       = one(module.app_tier[*].app_vm_private_ip)
}
