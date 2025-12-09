# Storage Blob Data Contributor role for App Registration service principal
resource "azurerm_role_assignment" "storage_blob_workload" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.workload.object_id
}

# Storage Blob Data Contributor role for VM-trusted App Registration
resource "azurerm_role_assignment" "storage_blob_vm_trusted" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.vm_trusted.object_id
}
