variable "deploy_enabled" {
  description = "Default-off guard. When false, `terraform plan` shows zero Azure resources."
  type        = bool
  default     = false
}

variable "location" {
  type    = string
  default = "canadacentral"
}

variable "azure_subscription_id" {
  description = "Target subscription. Placeholder default passes offline validation only."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "resource_group_name" {
  type    = string
  default = "rg-two-tier-network"
}

variable "vnet_address_space" {
  description = "Hub VNet CIDR. Subnets are carved from this range in modules/hub_network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "admin_username" {
  description = "Linux VM admin account. Login is SSH-key only (no passwords)."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key. REQUIRED before enabling deploy_enabled; empty default keeps the offline scaffold inert."
  type        = string
  default     = ""
}

variable "web_vm_count" {
  description = "Number of Nginx web VMs behind the load balancer."
  type        = number
  default     = 2

  validation {
    condition     = var.web_vm_count >= 1 && var.web_vm_count <= 5
    error_message = "web_vm_count must be between 1 and 5."
  }
}

variable "vm_size" {
  description = "SKU for web and app VMs. Keep low-cost B-series for the lab."
  type        = string
  default     = "Standard_B1s"
}

variable "bastion_sku" {
  description = "Bastion SKU. Basic is the cheapest standing option; Standard adds native client + host scaling."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.bastion_sku)
    error_message = "bastion_sku must be Basic or Standard."
  }
}

variable "tags" {
  type = map(string)
  default = {
    environment = "portfolio-lab"
    managed_by  = "terraform"
  }
}
