# Offline-safe defaults: the deploy gate stays closed. To prepare a real
# deployment (owner approval required first), set deploy_enabled = true,
# provide azure_subscription_id and an admin_ssh_public_key via -var-file /
# environment, then review terraform plan BEFORE any apply.
deploy_enabled       = false
location             = "canadacentral"
bastion_sku          = "Basic"
web_vm_count         = 2
vm_size              = "Standard_B1s"
admin_ssh_public_key = ""
