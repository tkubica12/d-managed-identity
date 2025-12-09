# AKS control plane identity needs Contributor on the node resource group
# and Network Contributor on the subnet
resource "azurerm_role_assignment" "aks_control_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control.principal_id
}

resource "azurerm_role_assignment" "aks_control_network" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control.principal_id
}

# Kubelet identity needs Managed Identity Operator to assign identities to nodes
resource "azurerm_role_assignment" "aks_kubelet_mi_operator" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks_kubelet.principal_id
}

# Kubelet identity - placeholder for ACR pull (if ACR is added later)
resource "azurerm_role_assignment" "aks_kubelet_acr_pull" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.aks_kubelet.principal_id
}
