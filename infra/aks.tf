# AKS Cluster with workload identity and OIDC enabled
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${local.base_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${local.base_name}"
  node_resource_group = "rg-aks-nodes-${local.base_name}"

  # Enable OIDC issuer and workload identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_B2s"
    vnet_subnet_id = azurerm_subnet.aks.id

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_control.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.aks_kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.aks_kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_kubelet.id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
    outbound_type       = "userAssignedNATGateway"
  }

  depends_on = [
    azurerm_role_assignment.aks_control_contributor,
    azurerm_role_assignment.aks_kubelet_acr_pull,
    azurerm_subnet_nat_gateway_association.aks
  ]
}
