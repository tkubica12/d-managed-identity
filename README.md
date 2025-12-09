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

