variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "web_subnet_id" {
  type = string
}

variable "web_vm_count" {
  description = "Nginx VMs behind the load balancer."
  type        = number
  default     = 2

  validation {
    condition     = var.web_vm_count >= 1 && var.web_vm_count <= 5
    error_message = "web_vm_count must be between 1 and 5."
  }
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key; SSH-key-only login (passwords disabled)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
