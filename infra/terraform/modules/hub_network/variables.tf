variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type    = string
  default = "vnet-two-tier"
}

variable "address_space" {
  description = "VNet CIDR. Subnets are carved with cidrsubnet(): web .1.0/24, app .2.0/24, bastion .250.0/26."
  type        = list(string)
  default     = ["10.10.0.0/16"]

  validation {
    condition     = length(var.address_space) == 1 && can(cidrhost(var.address_space[0], 0))
    error_message = "address_space must be exactly one valid IPv4 CIDR."
  }
}

variable "nat_gateway_name" {
  type    = string
  default = "nat-two-tier"
}

variable "tags" {
  type    = map(string)
  default = {}
}
