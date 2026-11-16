variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "bastion_subnet_id" {
  description = "AzureBastionSubnet id from modules/hub_network."
  type        = string
}

variable "bastion_sku" {
  description = "Basic: cheapest standing cost. Standard: native client, host scaling, tunneling."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.bastion_sku)
    error_message = "bastion_sku must be Basic or Standard."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
