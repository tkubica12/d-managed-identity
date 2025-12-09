# Managed Identity

## Managed Identity in VM

<details>
<summary>1. Connect to VM via Serial Console</summary>

```bash
az serial-console connect -n vm-manid-rnya -g rg-manid-rnya
```

</details>

<details>
<summary>2. Get token from metadata endpoint using curl</summary>

When VM has multiple managed identities (system-assigned + user-assigned), you must specify the `client_id` of the identity you want to use:

```bash
# First, get the client_id of the user-assigned managed identity
# You can find it in Azure Portal or use: az identity show -n <identity-name> -g <rg> --query clientId -o tsv
export AZURE_CLIENT_ID="528b5a7c-1730-4fb9-ae3d-d2fc246848e1"

# Get access token for Azure Storage using specific identity
TOKEN=$(curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/&client_id=$AZURE_CLIENT_ID" \
  | jq -r '.access_token')

echo $TOKEN
```

</details>

<details>
<summary>3. Access blob storage using token and curl</summary>

```bash
# Download a blob
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-ms-version: 2020-04-08" \
  "https://stmanidrnya.blob.core.windows.net/content/myfile.txt"
```

</details>

<details>
<summary>4. Use Python SDK with DefaultAzureCredential</summary>

When `AZURE_CLIENT_ID` environment variable is set, `DefaultAzureCredential` automatically uses that identity.

```bash
# Install Python and pip on Ubuntu 24.04
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

# Create and activate virtual environment (required on Ubuntu 24.04)
python3 -m venv .venv
source .venv/bin/activate

# Install packages
pip install azure-identity azure-storage-blob
```

```python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

# DefaultAzureCredential reads AZURE_CLIENT_ID from environment
# to determine which managed identity to use
credential = DefaultAzureCredential()

# Connect to blob storage
blob_service_client = BlobServiceClient(
    account_url="https://stmanidrnya.blob.core.windows.net",
    credential=credential
)

# Download a blob
blob_client = blob_service_client.get_blob_client(
    container="content",
    blob="myfile.txt"
)
content = blob_client.download_blob().readall()
print(content.decode('utf-8'))
```

</details>

## Managed Identity in AKS (Workload Identity)

<details>
<summary>1. Get AKS credentials and connect to cluster</summary>

```bash
# Get AKS credentials
az aks get-credentials -n aks-manid-rnya -g rg-manid-rnya --overwrite-existing

# Check demo pods are running
kubectl get pods -n demo
```

</details>

<details>
<summary>2. Jump to curl container and get Kubernetes token</summary>

```bash
# Exec into curl container
kubectl exec -it -n demo $(kubectl get pod -n demo -l app=curl-demo -o jsonpath='{.items[0].metadata.name}') -- sh

# Inside the container, the service account token is automatically mounted
# Check the projected token location
cat /var/run/secrets/azure/tokens/azure-identity-token

# Store the Kubernetes token in a variable
K8S_TOKEN=$(cat /var/run/secrets/azure/tokens/azure-identity-token)
echo $K8S_TOKEN
```

</details>

<details>
<summary>3. Exchange Kubernetes token for Entra token and access storage</summary>

```bash
# Inside the curl container
# AZURE_CLIENT_ID and AZURE_TENANT_ID are already set by workload identity webhook
echo $AZURE_CLIENT_ID

# Exchange Kubernetes token for Entra token scoped to Azure Storage
# Using sed to parse JSON since jq is not available in this minimal image
TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$AZURE_CLIENT_ID" \
  -d "scope=https://storage.azure.com/.default" \
  -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  -d "client_assertion=$K8S_TOKEN" \
  -d "grant_type=client_credentials" \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

echo $TOKEN

# Access blob storage with the Entra token
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-ms-version: 2020-04-08" \
  "https://stmanidrnya.blob.core.windows.net/content/myfile.txt"
```

</details>

<details>
<summary>4. Use Python SDK with DefaultAzureCredential</summary>

```bash
# Exec into python container
kubectl exec -it -n demo $(kubectl get pod -n demo -l app=python-demo -o jsonpath='{.items[0].metadata.name}') -- bash

# Install packages
pip install azure-identity azure-storage-blob

# Run Python - no code change needed compared to VM!
python3
```

```python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

# DefaultAzureCredential reads AZURE_CLIENT_ID from environment
# and uses workload identity automatically in AKS
credential = DefaultAzureCredential()

# Connect to blob storage
blob_service_client = BlobServiceClient(
    account_url="https://stmanidrnya.blob.core.windows.net",
    credential=credential
)

# Download a blob
blob_client = blob_service_client.get_blob_client(
    container="content",
    blob="myfile.txt"
)
content = blob_client.download_blob().readall()
print(content.decode('utf-8'))
```

The same Python code works in both VM and AKS! `DefaultAzureCredential` automatically detects the environment and uses the appropriate authentication method.

</details>

## App Registration Federation with Managed Identity or AKS

This section demonstrates how to use App Registrations federated with Managed Identity (VM) or AKS Workload Identity to access an external API exposed by another App Registration.

**Architecture:**
- `api-external-*` - App Registration exposing an API with `Data.Read.All` app role
- `app-workload-*` - App Registration federated with AKS (workload-sa), granted access to the external API
- `app-vm-trusted-*` - App Registration federated with VM managed identity (id-vm-*), granted access to the external API

<details>
<summary>1. Get token for external API from AKS (curl-workload container)</summary>

```bash
# Exec into curl-workload container (uses app-workload federated to AKS)
kubectl exec -it -n demo $(kubectl get pod -n demo -l app=curl-workload -o jsonpath='{.items[0].metadata.name}') -- sh

# Check environment variables set by workload identity webhook
echo "Client ID: $AZURE_CLIENT_ID"
echo "Tenant ID: $AZURE_TENANT_ID"

# Get Kubernetes service account token
K8S_TOKEN=$(cat /var/run/secrets/azure/tokens/azure-identity-token)

# Exchange for token scoped to the external API (use the API's Application ID URI)
# Replace <base_name> with your actual base name (e.g., manid-rnya)
API_SCOPE="api://fa014a7d-885d-4ab1-810c-b8059fdfb448/.default"

TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$AZURE_CLIENT_ID" \
  -d "scope=$API_SCOPE" \
  -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  -d "client_assertion=$K8S_TOKEN" \
  -d "grant_type=client_credentials" \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

echo $TOKEN

# The token contains the app role in the 'roles' claim
# You can decode it at https://jwt.ms to verify
```

</details>

<details>
<summary>2. Get token for external API from VM (using managed identity federation)</summary>

```bash
# Connect to VM via serial console
az serial-console connect -n vm-manid-rnya -g rg-manid-rnya

# Set the client IDs
export AZURE_CLIENT_ID="<vm-managed-identity-client-id>"  # id-vm-* client ID
export APP_CLIENT_ID="<app-vm-trusted-client-id>"         # app-vm-trusted-* client ID
export AZURE_TENANT_ID="<your-tenant-id>"

# Step 1: Get token from VM metadata endpoint for the managed identity
# The audience is the app registration that trusts this managed identity
MI_TOKEN=$(curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=api://AzureADTokenExchange&client_id=$AZURE_CLIENT_ID" \
  | jq -r '.access_token')

echo "Managed Identity Token: $MI_TOKEN"

# Step 2: Exchange the MI token for a token scoped to the external API
# This uses the app-vm-trusted as the client (which trusts the MI via federation)
API_SCOPE="api://api-external-<base_name>/.default"

API_TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$APP_CLIENT_ID" \
  -d "scope=$API_SCOPE" \
  -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  -d "client_assertion=$MI_TOKEN" \
  -d "grant_type=client_credentials" \
  | jq -r '.access_token')

echo "API Token: $API_TOKEN"

# The token contains the 'Data.Read.All' role granted to app-vm-trusted
```

</details>

<details>
<summary>3. Understanding the token exchange flow</summary>

**AKS Workload Identity Flow:**
```
Kubernetes SA Token → Exchange for App Registration Token → Access External API
     (workload-sa)        (app-workload-*)                  (api-external-*)
```

**VM Managed Identity Flow:**
```
MI Token (id-vm-*) → Exchange for App Registration Token → Access External API
                          (app-vm-trusted-*)                (api-external-*)
```

Both flows use the OAuth 2.0 client credentials grant with JWT bearer assertion:
- `client_id`: The app registration that will be the identity of the token
- `client_assertion`: The federated token (K8s SA token or MI token)
- `scope`: The target API's scope (Application ID URI + /.default)
- The `roles` claim in the resulting token contains the granted app roles

This pattern enables:
- **External SaaS integration**: Access third-party APIs that require app registrations
- **Multi-tenant scenarios**: Access resources in other tenants
- **Fine-grained permissions**: Use app roles to control access to your APIs

</details>

