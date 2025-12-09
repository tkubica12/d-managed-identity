# App Registration (Service Principal) for workload identity demo
resource "azuread_application" "workload" {
  display_name = "app-workload-${local.base_name}"
}

resource "azuread_service_principal" "workload" {
  client_id = azuread_application.workload.client_id
}

# Federated credential for App Registration with AKS workload identity
resource "azuread_application_federated_identity_credential" "workload_aks" {
  application_id = azuread_application.workload.id
  display_name   = "fed-aks-workload-sa"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject        = "system:serviceaccount:demo:workload-sa"
}

# App Registration (Service Principal) that trusts VM managed identity
resource "azuread_application" "vm_trusted" {
  display_name = "app-vm-trusted-${local.base_name}"
}

resource "azuread_service_principal" "vm_trusted" {
  client_id = azuread_application.vm_trusted.client_id
}

# Federated credential for App Registration trusting VM managed identity
resource "azuread_application_federated_identity_credential" "vm_trusted" {
  application_id = azuread_application.vm_trusted.id
  display_name   = "fed-vm-identity"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
  subject        = azurerm_user_assigned_identity.vm.principal_id
}

# =============================================================================
# External API App Registration - exposes API that other apps can call
# =============================================================================

resource "random_uuid" "api_scope_id" {}
resource "random_uuid" "api_role_id" {}

# App Registration exposing an API
resource "azuread_application" "external_api" {
  display_name = "api-external-${local.base_name}"

  api {
    # Set requested_access_token_version = 2 to allow flexible identifier URIs
    requested_access_token_version = 2

    # Expose a scope (delegated permission) - for user-based access
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access the external API on behalf of the signed-in user"
      admin_consent_display_name = "Access External API"
      enabled                    = true
      id                         = random_uuid.api_scope_id.result
      type                       = "Admin"
      value                      = "Data.Read"
    }
  }

  # Expose an app role (application permission) - for service-to-service access
  app_role {
    allowed_member_types = ["Application"]
    description          = "Allow the application to read data from the external API"
    display_name         = "Data.Read.All"
    enabled              = true
    id                   = random_uuid.api_role_id.result
    value                = "Data.Read.All"
  }
}

resource "azuread_service_principal" "external_api" {
  client_id = azuread_application.external_api.client_id
}

# Set the Application ID URI after the app is created (using client_id to comply with tenant policy)
resource "azuread_application_identifier_uri" "external_api" {
  application_id = azuread_application.external_api.id
  identifier_uri = "api://${azuread_application.external_api.client_id}"
}

# Grant app-workload access to the external API (app role assignment)
resource "azuread_app_role_assignment" "workload_to_api" {
  app_role_id         = random_uuid.api_role_id.result
  principal_object_id = azuread_service_principal.workload.object_id
  resource_object_id  = azuread_service_principal.external_api.object_id
}

# Grant app-vm-trusted access to the external API (app role assignment)
resource "azuread_app_role_assignment" "vm_trusted_to_api" {
  app_role_id         = random_uuid.api_role_id.result
  principal_object_id = azuread_service_principal.vm_trusted.object_id
  resource_object_id  = azuread_service_principal.external_api.object_id
}
