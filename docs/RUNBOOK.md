# Runbook – Operative Aufgaben

## Inhaltsverzeichnis

1. [Lokal starten / stoppen](#lokal-starten--stoppen)
2. [Logs einsehen](#logs-einsehen)
3. [Container neu bauen](#container-neu-bauen)
4. [In Azure deployen](#in-azure-deployen)
5. [Azure-Ressourcen prüfen](#azure-ressourcen-prüfen)
6. [Troubleshooting](#troubleshooting)
7. [Kosten überwachen](#kosten-überwachen)

---

## Lokal starten / stoppen

### Start

```bash
# Alles auf einmal (empfohlen)
docker compose up

# Im Hintergrund
docker compose up -d

# Mit neuem Build (nach Code-Änderungen)
docker compose up --build
```

### Stoppen

```bash
# Container stoppen, Volumes bleiben
docker compose down

# Container + Volumes löschen
docker compose down -v

# Alles wegwerfen (Images, Container, Netzwerke)
docker compose down -v --rmi all
```

### Status prüfen

```bash
docker compose ps

# Detailliert
docker ps -a --filter "name=weatherwise"
```

---

## Logs einsehen

### Alle Services

```bash
docker compose logs -f
```

### Einzelner Service

```bash
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f redis

# Nur letzte 50 Zeilen
docker compose logs --tail 50 backend
```

### Azure-Logs (Cloud)

```powershell
# Container Apps Logs
az containerapp logs show `
    --name weatherwise-backend-dev `
    --resource-group weatherwise-dev-rg `
    --follow

# Log Analytics Query
az monitor log-analytics query `
    --workspace <workspace-id> `
    --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'weatherwise-backend-dev' | take 50"
```

---

## Container neu bauen

### Nach Code-Änderung

```bash
# Backend neu bauen + starten
docker compose up --build backend

# Frontend neu bauen + starten
docker compose up --build frontend

# Alles neu
docker compose up --build
```

### Cache umgehen (kompletter Rebuild)

```bash
docker compose build --no-cache
docker compose up
```

---

## In Azure deployen

### Automatischer Deploy via Git

```bash
# DEV: push auf develop
git checkout develop
git add .
git commit -m "feat: neue Funktion"
git push origin develop
# → GitHub Actions startet automatisch deploy-dev.yml

# PROD: merge develop → main
git checkout main
git merge develop
git push origin main
# → GitHub Actions startet automatisch deploy-prod.yml
```

### Manueller Deploy (Notfall)

```powershell
# DEV
az deployment group create `
    --resource-group weatherwise-dev-rg `
    --template-file infra/main.bicep `
    --parameters infra/parameters/dev.parameters.json `
    --parameters openWeatherApiKey="<key>"

# PROD
az deployment group create `
    --resource-group weatherwise-prod-rg `
    --template-file infra/main.bicep `
    --parameters infra/parameters/prod.parameters.json `
    --parameters openWeatherApiKey="<key>"
```

### Bicep-Vorschau (was würde sich ändern?)

```powershell
az deployment group what-if `
    --resource-group weatherwise-dev-rg `
    --template-file infra/main.bicep `
    --parameters infra/parameters/dev.parameters.json `
    --parameters openWeatherApiKey="<key>"
```

---

## Azure-Ressourcen prüfen

### Alle Ressourcen auflisten

```powershell
# DEV
az resource list --resource-group weatherwise-dev-rg --output table

# PROD
az resource list --resource-group weatherwise-prod-rg --output table
```

### Container App URLs

```powershell
# Frontend-URL
az containerapp show `
    --name weatherwise-frontend-dev `
    --resource-group weatherwise-dev-rg `
    --query properties.configuration.ingress.fqdn `
    --output tsv

# Backend-URL
az containerapp show `
    --name weatherwise-backend-dev `
    --resource-group weatherwise-dev-rg `
    --query properties.configuration.ingress.fqdn `
    --output tsv
```

### Revisions ansehen

```powershell
az containerapp revision list `
    --name weatherwise-backend-dev `
    --resource-group weatherwise-dev-rg `
    --output table
```

### Container App neu starten

```powershell
# Aktive Revision deaktivieren + neu starten
az containerapp revision restart `
    --name weatherwise-backend-dev `
    --resource-group weatherwise-dev-rg `
    --revision <revision-name>
```

---

## Troubleshooting

### Lokales Setup

| Problem | Lösung |
|---------|--------|
| Port 8000 oder 8080 ist belegt | `netstat -ano \| findstr :8000` (Windows) und Prozess beenden |
| `OPENWEATHER_API_KEY muss gesetzt sein` | `.env`-Datei prüfen, Schlüssel eintragen |
| Frontend zeigt "Backend nicht erreichbar" | `docker compose ps` → ist Backend gesund? `docker compose logs backend` |
| Redis-Verbindung schlägt fehl | Backend prüft `REDIS_URL`. Default `redis://redis:6379/0` |
| `docker compose up` ist sehr langsam | Erste Build dauert 3-5 min. Folgende Builds nutzen Cache und sind < 1 min |
| Frontend-Hot-Reload geht nicht | Container hat statischen Build. Für Live-Entwicklung `cd frontend && npm run dev` |

### Azure-Deploy

| Problem | Lösung |
|---------|--------|
| `az login` fragt nach Subscription | `az account set --subscription "Azure for Students"` |
| ACR-Push schlägt fehl | RBAC-Rolle "AcrPush" auf SP prüfen |
| Key Vault Zugriff verweigert | RBAC-Rolle "Key Vault Secrets User" auf Managed Identity prüfen |
| Bicep What-If zeigt "unchanged" | Image-Tag in Parametern erhöhen (`v1.0.1` statt `latest`) |
| Container App startet nicht | `az containerapp logs show ...` für Detail-Logs |
| Healthcheck schlägt fehl | `/health` lokal prüfen → wenn lokal OK, dann Probe-Konfiguration in Bicep prüfen |

### CI/CD

| Problem | Lösung |
|---------|--------|
| GitHub Actions Workflow läuft nicht | Repo-Settings → Actions → Permissions: "Read and write" |
| `AZURE_CREDENTIALS` schlägt fehl | JSON-Format prüfen, in Anführungszeichen einfügen |
| Trivy findet Vulnerabilities | `severity: HIGH` Builds brechen Pipeline. Updates abwarten oder ignorieren |
| Docker Build out of memory | GitHub-Runner hat 7 GB. Multi-Stage hilft. Sonst Self-Hosted Runner |

---

## Kosten überwachen

### Aktuelle Kosten ansehen

```powershell
# Diesen Monat
az consumption usage list `
    --start-date "2026-05-01" `
    --end-date "2026-05-31" `
    --query "[].{Service:meterName, Cost:pretaxCost}" `
    --output table
```

### Budget-Alert einrichten

```powershell
az consumption budget create `
    --budget-name weatherwise-monthly `
    --amount 30 `
    --time-grain Monthly `
    --start-date 2026-05-01 `
    --end-date 2026-12-31
```

### Kosten-Tipps

1. **Scale-to-Zero in DEV**: `minReplicas: 0` spart Geld, wenn niemand testet
2. **Single-Region**: Alle Ressourcen in `switzerlandnorth` → kein Cross-Region-Traffic
3. **Log Analytics dailyQuotaGb: 1**: Verhindert Log-Kosten-Explosion
4. **ACR Basic SKU**: Reicht für ein Projekt (Standard wäre 4x teurer)
5. **Nach Bewertung teardown**: `.\scripts\azure-teardown.ps1` löscht alles

### Geschätzte monatliche Kosten

| Ressource | DEV | PROD |
|-----------|-----|------|
| Container Apps (Consumption) | ~5 CHF | ~15 CHF |
| Container Registry (Basic) | 5 CHF | 5 CHF |
| Key Vault (Standard) | < 1 CHF | < 1 CHF |
| Log Analytics (1 GB/Tag) | ~5 CHF | ~5 CHF |
| Application Insights | inkl. | inkl. |
| **Total** | **~16 CHF** | **~26 CHF** |
| **Beide Umgebungen** | | **~42 CHF / Monat** |

$100 Azure-for-Students-Credit reicht somit für **ca. 2,5 Monate** Betrieb.
