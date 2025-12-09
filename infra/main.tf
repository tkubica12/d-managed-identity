# Generate random string for resource naming uniqueness
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = false
}

# Common locals for resource naming and tagging
locals {
  location               = var.location
  prefix                 = "${var.project_name}-${random_string.suffix.result}"
  base_name              = "${var.project_name}-${random_string.suffix.result}"
  base_name_alphanumeric = replace(local.base_name, "/[^a-zA-Z0-9]/", "")
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}"
  location = local.location

  tags = {
    SecurityControl = "ignore"
  }
}

# Get current client configuration
data "azurerm_client_config" "current" {}
