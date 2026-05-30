# =============================================================================
# WeatherWise - Azure Initial-Setup
# =============================================================================
# Dieses Skript bereitet alle Azure-Ressourcen vor, die für die
# CI/CD-Pipelines benötigt werden:
#   - Resource Groups (dev + prod)
#   - Container Registries (dev + prod)
#   - Service Principal für GitHub Actions
#   - Ausgabe der GitHub Secrets, die in das Repository eingetragen werden
#
# Aufruf:  .\scripts\azure-setup.ps1
# Voraussetzung:
#   - Azure CLI installiert (https://aka.ms/installazurecli)
#   - Bei Azure angemeldet: az login
# =============================================================================

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Konfiguration
# -----------------------------------------------------------------------------
$LOCATION = "switzerlandnorth"
$PROJECT = "weatherwise"
$SP_NAME = "github-actions-weatherwise"

$RG_DEV = "weatherwise-dev-rg"
$RG_PROD = "weatherwise-prod-rg"

$ACR_DEV = "weatherwiseacrdev"
$ACR_PROD = "weatherwiseacrprod"

# -----------------------------------------------------------------------------
# Start
# -----------------------------------------------------------------------------
Write-Host "==> WeatherWise - Azure Initial-Setup" -ForegroundColor Cyan
Write-Host ""

# Prüfen, ob Azure CLI installiert ist
try {
    $azVersion = az version --output tsv 2>&1
} catch {
    Write-Host "[X] Azure CLI nicht gefunden." -ForegroundColor Red
    Write-Host "    Installation: https://aka.ms/installazurecli" -ForegroundColor Yellow
    exit 1
}

# Subscription ID holen
$SUBSCRIPTION_ID = az account show --query id --output tsv
$SUBSCRIPTION_NAME = az account show --query name --output tsv

Write-Host "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)" -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "Mit dieser Subscription fortfahren? (j/n)"
if ($confirm -ne "j") {
    Write-Host "Abgebrochen. Wechsle mit: az account set --subscription <id>" -ForegroundColor Yellow
    exit 0
}

# -----------------------------------------------------------------------------
# Schritt 1: Resource Provider registrieren
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Resource Provider werden registriert" -ForegroundColor Cyan

$providers = @(
    "Microsoft.App",
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.ManagedIdentity"
)

foreach ($provider in $providers) {
    Write-Host "    Registriere $provider..." -ForegroundColor Gray
    az provider register --namespace $provider --wait | Out-Null
}
Write-Host "    [OK] Alle Provider registriert" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Schritt 2: Resource Groups erstellen
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Resource Groups werden erstellt" -ForegroundColor Cyan

az group create `
    --name $RG_DEV `
    --location $LOCATION `
    --tags project=$PROJECT environment=dev "owner=Mehmet Ali Gür" | Out-Null
Write-Host "    [OK] $RG_DEV" -ForegroundColor Green

az group create `
    --name $RG_PROD `
    --location $LOCATION `
    --tags project=$PROJECT environment=prod "owner=Mehmet Ali Gür" | Out-Null
Write-Host "    [OK] $RG_PROD" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Schritt 3: Container Registries
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Container Registries werden erstellt" -ForegroundColor Cyan

az acr create `
    --resource-group $RG_DEV `
    --name $ACR_DEV `
    --sku Basic `
    --location $LOCATION `
    --admin-enabled false | Out-Null
Write-Host "    [OK] $ACR_DEV.azurecr.io" -ForegroundColor Green

az acr create `
    --resource-group $RG_PROD `
    --name $ACR_PROD `
    --sku Basic `
    --location $LOCATION `
    --admin-enabled false | Out-Null
Write-Host "    [OK] $ACR_PROD.azurecr.io" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Schritt 4: Service Principal für GitHub Actions
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Service Principal für GitHub Actions wird erstellt" -ForegroundColor Cyan

# Alte SP löschen, falls vorhanden
az ad sp list --display-name $SP_NAME --query "[].appId" --output tsv | ForEach-Object {
    if ($_) {
        Write-Host "    Lösche alten Service Principal..." -ForegroundColor Yellow
        az ad sp delete --id $_ | Out-Null
    }
}

# Neuen SP erstellen mit Contributor-Rechten auf beide RGs
$SCOPES = "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_DEV /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_PROD"

$spJson = az ad sp create-for-rbac `
    --name $SP_NAME `
    --role Contributor `
    --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_DEV /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_PROD `
    --json-auth

Write-Host "    [OK] Service Principal erstellt" -ForegroundColor Green

# SP ID extrahieren für RBAC-Rollen
$SP_OBJECT = $spJson | ConvertFrom-Json
$SP_APP_ID = $SP_OBJECT.clientId
$SP_OBJECT_ID = az ad sp show --id $SP_APP_ID --query id --output tsv

# -----------------------------------------------------------------------------
# Schritt 5: SP-Rollen für ACR-Push und Key Vault Admin
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "==> Zusätzliche Rollen werden zugewiesen" -ForegroundColor Cyan

# ACR Push auf beide Registries
az role assignment create `
    --assignee-object-id $SP_OBJECT_ID `
    --assignee-principal-type ServicePrincipal `
    --role AcrPush `
    --scope (az acr show --name $ACR_DEV --query id --output tsv) | Out-Null
Write-Host "    [OK] AcrPush auf $ACR_DEV" -ForegroundColor Green

az role assignment create `
    --assignee-object-id $SP_OBJECT_ID `
    --assignee-principal-type ServicePrincipal `
    --role AcrPush `
    --scope (az acr show --name $ACR_PROD --query id --output tsv) | Out-Null
Write-Host "    [OK] AcrPush auf $ACR_PROD" -ForegroundColor Green

# Key Vault Administrator (für Secret-Management während Deployment)
az role assignment create `
    --assignee-object-id $SP_OBJECT_ID `
    --assignee-principal-type ServicePrincipal `
    --role "Key Vault Administrator" `
    --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_DEV | Out-Null
Write-Host "    [OK] Key Vault Administrator auf $RG_DEV" -ForegroundColor Green

az role assignment create `
    --assignee-object-id $SP_OBJECT_ID `
    --assignee-principal-type ServicePrincipal `
    --role "Key Vault Administrator" `
    --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_PROD | Out-Null
Write-Host "    [OK] Key Vault Administrator auf $RG_PROD" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Schritt 6: GitHub Secrets ausgeben
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "  WICHTIG: Folgende Secrets in GitHub eintragen" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "GitHub -> Settings -> Secrets and variables -> Actions" -ForegroundColor Cyan
Write-Host ""
Write-Host "Secret-Name:  AZURE_CREDENTIALS" -ForegroundColor White
Write-Host "Secret-Wert (als JSON):" -ForegroundColor White
Write-Host ""
Write-Host $spJson -ForegroundColor Green
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Zusätzliche Secrets (manuell setzen):" -ForegroundColor Cyan
Write-Host "  - OPENWEATHER_API_KEY_DEV  = <dein-openweather-key>"
Write-Host "  - OPENWEATHER_API_KEY_PROD = <dein-openweather-key>"
Write-Host "  - DEV_BACKEND_URL          = (wird nach erstem Deploy bekannt)"
Write-Host "  - PROD_BACKEND_URL         = (wird nach erstem Deploy bekannt)"
Write-Host ""
Write-Host "==> Setup abgeschlossen!" -ForegroundColor Green
Write-Host ""

# Optional: SP-JSON in Datei speichern (NICHT in Git!)
$spFile = "azure-credentials.local.json"
$spJson | Out-File -FilePath $spFile -Encoding utf8
Write-Host "Service Principal Credentials wurden in '$spFile' gespeichert." -ForegroundColor Cyan
Write-Host "DIESE DATEI IST IN .gitignore - NIEMALS COMMITEN!" -ForegroundColor Red
