# =============================================================================
# WeatherWise - Azure Teardown (Alle Ressourcen löschen)
# =============================================================================
# WARNUNG: Dieses Skript löscht ALLE WeatherWise-Ressourcen in Azure!
# Verwende es nur, wenn du das Projekt komplett abbauen willst,
# oder nach der Bewertung, um $100 Credit zu sparen.
#
# Aufruf:  .\scripts\azure-teardown.ps1
# =============================================================================

$ErrorActionPreference = "Continue"

$RG_DEV = "weatherwise-dev-rg"
$RG_PROD = "weatherwise-prod-rg"

Write-Host "==> WeatherWise - Azure Teardown" -ForegroundColor Red
Write-Host ""
Write-Host "Dieses Skript löscht UNWIDERRUFLICH:" -ForegroundColor Yellow
Write-Host "  - Resource Group: $RG_DEV (mit allen Ressourcen)"
Write-Host "  - Resource Group: $RG_PROD (mit allen Ressourcen)"
Write-Host "  - Service Principal: github-actions-weatherwise"
Write-Host ""

$confirm = Read-Host "WIRKLICH alle Ressourcen löschen? (LOESCHEN/n)"
if ($confirm -ne "LOESCHEN") {
    Write-Host "Abgebrochen." -ForegroundColor Yellow
    exit 0
}

# Resource Groups löschen (asynchron)
Write-Host ""
Write-Host "==> Resource Groups werden gelöscht (dauert 5-15 Minuten)..." -ForegroundColor Cyan

az group delete --name $RG_DEV --yes --no-wait
Write-Host "    [...] $RG_DEV wird im Hintergrund gelöscht" -ForegroundColor Gray

az group delete --name $RG_PROD --yes --no-wait
Write-Host "    [...] $RG_PROD wird im Hintergrund gelöscht" -ForegroundColor Gray

# Service Principal löschen
Write-Host ""
Write-Host "==> Service Principal wird gelöscht" -ForegroundColor Cyan
$spId = az ad sp list --display-name "github-actions-weatherwise" --query "[0].appId" --output tsv
if ($spId) {
    az ad sp delete --id $spId
    Write-Host "    [OK] Service Principal gelöscht" -ForegroundColor Green
} else {
    Write-Host "    [..] Kein Service Principal gefunden" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==> Teardown initiiert. Vollständige Löschung dauert 5-15 Minuten." -ForegroundColor Green
Write-Host "    Status prüfen: az group list --query \"[?name=='$RG_DEV' || name=='$RG_PROD']\"" -ForegroundColor Cyan
