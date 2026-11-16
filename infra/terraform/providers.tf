provider "azurerm" {
  # Placeholder satisfies offline validation; set ARM_SUBSCRIPTION_ID or a
  # tfvars value before any approved deployment.
  subscription_id = var.azure_subscription_id
  features {}
}
