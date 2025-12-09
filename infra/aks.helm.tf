# Federated credential for service identity with AKS workload identity
resource "azurerm_federated_identity_credential" "service_aks" {
  name                = "fed-aks-demo-sa"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.service.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:demo:demo-sa"
}

# Deploy demo Helm chart
resource "helm_release" "demo" {
  name             = "demo"
  chart            = "${path.module}/../charts/demo"
  namespace        = "demo"
  create_namespace = true

  set {
    name  = "azureClientId"
    value = azurerm_user_assigned_identity.service.client_id
  }

  set {
    name  = "serviceAccountName"
    value = "demo-sa"
  }

  set {
    name  = "namespace"
    value = "demo"
  }

  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_federated_identity_credential.service_aks
  ]
}
