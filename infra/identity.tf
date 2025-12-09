# User-assigned managed identity for Virtual Machines
resource "azurerm_user_assigned_identity" "vm" {
  name                = "id-vm-${local.base_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# User-assigned managed identity for services (e.g., App Service, Functions)
resource "azurerm_user_assigned_identity" "service" {
  name                = "id-service-${local.base_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# User-assigned managed identity for AKS control plane
resource "azurerm_user_assigned_identity" "aks_control" {
  name                = "id-akscontrol-${local.base_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# User-assigned managed identity for AKS kubelet
resource "azurerm_user_assigned_identity" "aks_kubelet" {
  name                = "id-akskubelet-${local.base_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}
