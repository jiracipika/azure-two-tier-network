variable "deploy_enabled" {
  description = "Default-off guard. No Azure resources are declared yet."
  type = bool
  default = false
}
variable "location" {
  type = string
  default = "canadacentral"
}
