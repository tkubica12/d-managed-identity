# Storage Account
resource "azurerm_storage_account" "main" {
  name                            = "st${local.base_name_alphanumeric}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
}

# Storage Container
resource "azurerm_storage_container" "main" {
  name                  = "content"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"

  depends_on = [azurerm_role_assignment.storage_blob_self]
}

# Upload myfile.txt to container
resource "azurerm_storage_blob" "myfile" {
  name                   = "myfile.txt"
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = azurerm_storage_container.main.name
  type                   = "Block"
  source                 = "${path.module}/content/myfile.txt"

  depends_on = [azurerm_role_assignment.storage_blob_self]
}
