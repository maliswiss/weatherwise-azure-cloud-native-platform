# =============================================================================
# WeatherWise - Lokales Start-Skript (Windows PowerShell)
# =============================================================================
# Erfüllt K9 (Reproduzierbarkeit): Ein Befehl startet alles.
# Aufruf:  .\start.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "==> WeatherWise - lokales Setup wird gestartet" -ForegroundColor Cyan

# .env prüfen
if (-Not (Test-Path ".env")) {
    Write-Host "[!] Keine .env-Datei gefunden." -ForegroundColor Yellow
    Write-Host "    .env.example wird kopiert - bitte API-Key eintragen!" -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host ""
    Write-Host "    Datei .env öffnen und OPENWEATHER_API_KEY setzen, dann erneut starten." -ForegroundColor Yellow
    exit 1
}

# Docker prüfen
try {
    docker version | Out-Null
} catch {
    Write-Host "[X] Docker läuft nicht. Bitte Docker Desktop starten." -ForegroundColor Red
    exit 1
}

Write-Host "==> Images werden gebaut..." -ForegroundColor Cyan
docker compose build

Write-Host "==> Services werden gestartet..." -ForegroundColor Cyan
docker compose up -d

Write-Host ""
Write-Host "==> WeatherWise läuft!" -ForegroundColor Green
Write-Host "    Frontend:  http://localhost:8080"
Write-Host "    Backend:   http://localhost:8000"
Write-Host "    API-Docs:  http://localhost:8000/docs"
Write-Host "    Health:    http://localhost:8000/health"
Write-Host ""
Write-Host "    Logs ansehen:    docker compose logs -f"
Write-Host "    Services stoppen: docker compose down"
