# Storage Blob Data Contributor role for VM managed identity
resource "azurerm_role_assignment" "storage_blob_vm" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.vm.principal_id
}

# Storage Blob Data Contributor role for Service managed identity
resource "azurerm_role_assignment" "storage_blob_service" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.service.principal_id
}

# Storage Blob Data Contributor role for current user (self)
resource "azurerm_role_assignment" "storage_blob_self" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
