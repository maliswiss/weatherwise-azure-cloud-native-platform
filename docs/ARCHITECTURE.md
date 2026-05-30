# Architektur-Übersicht

## Systemkontext

```mermaid
graph LR
    User((User<br/>Browser)) -->|HTTPS| App[WeatherWise<br/>System]
    App -->|HTTPS| OWM[(OpenWeatherMap<br/>API)]

    style User fill:#bbf,stroke:#333
    style OWM fill:#fdd,stroke:#333
    style App fill:#dfd,stroke:#333
```

## Container-Diagramm

```mermaid
graph TB
    User((User Browser))

    subgraph "Azure Container Apps Environment"
        Frontend["<b>Frontend</b><br/>React 19 + Nginx<br/>Port 8080"]
        Backend["<b>Backend</b><br/>FastAPI Python 3.12<br/>Port 8000"]
        Redis["<b>Redis</b><br/>Redis 7 Alpine<br/>Port 6379 (intern)"]
    end

    subgraph "Azure Management"
        KV["Azure Key Vault<br/>OPENWEATHER_API_KEY"]
        AI["Application Insights<br/>Logs + Metrics"]
        ACR["Container Registry<br/>weatherwiseacr*"]
        LA["Log Analytics<br/>Workspace"]
    end

    OWM[(OpenWeatherMap API)]

    User -->|HTTPS| Frontend
    Frontend -->|HTTPS /api/*| Backend
    Backend -->|TCP intern| Redis
    Backend -->|HTTPS| OWM
    Backend -.->|Managed Identity| KV
    Backend -.->|Telemetry| AI
    Frontend -.->|Logs| LA
    Backend -.->|Logs| LA
    ACR -.->|Pull Image| Frontend
    ACR -.->|Pull Image| Backend
```

## Deployment-Pipeline

```mermaid
sequenceDiagram
    actor Dev as Entwickler
    participant GH as GitHub
    participant CI as GitHub Actions
    participant ACR as Azure Container<br/>Registry
    participant ACA as Azure Container<br/>Apps

    Dev->>GH: git push develop
    GH->>CI: Webhook auslösen
    CI->>CI: Lint (Ruff)
    CI->>CI: Test (Pytest)
    CI->>CI: Trivy Scan
    CI->>CI: Docker Build (Multi-Stage)
    CI->>ACR: Push Images mit Tag
    CI->>ACA: az containerapp update
    ACA->>ACA: Healthcheck<br/>Rolling Update
    ACA-->>CI: Deployment OK
    CI-->>Dev: Status: Success
```

## Sicherheitsarchitektur

```mermaid
graph TB
    subgraph "Browser"
        UI[Frontend SPA]
    end

    subgraph "Public Internet"
        TLS[TLS 1.2+ Termination<br/>Azure Front Door]
    end

    subgraph "Container Apps Environment<br/>(virtual network)"
        FE[Frontend Container<br/>Non-Root user 'nginx']
        BE[Backend Container<br/>Non-Root user 'appuser']
        RD[Redis Container<br/>nur intern erreichbar]
    end

    subgraph "Azure Identity"
        MI[Managed Identity]
    end

    subgraph "Azure Vault"
        KV[Key Vault]
        SEC[OpenWeather API Key]
    end

    UI -->|HTTPS| TLS
    TLS -->|HTTPS| FE
    FE -->|HTTPS| BE
    BE -.->|TCP intern| RD
    BE -.->|Token Auth| MI
    MI -.->|Get Secret| KV
    KV -.- SEC

    style TLS fill:#ffe,stroke:#333
    style KV fill:#fdd,stroke:#333
    style MI fill:#dfd,stroke:#333
```

## Lifecycle eines API-Aufrufs

1. **User-Aktion:** Tippt "Bern" und klickt **Suchen**
2. **Frontend:** `fetch('https://backend.../api/weather?city=Bern')`
3. **Backend Empfang:**
   - Validierung der Query-Parameter via Pydantic
   - Cache-Key bilden: `weather:city:bern:metric`
4. **Cache-Check:**
   - **HIT** → Sofort JSON zurückgeben (typisch < 10ms)
   - **MISS** → Weiter zu Schritt 5
5. **OpenWeatherMap-Call:**
   - `httpx.AsyncClient` GET-Request mit API-Key
   - Timeout 10 Sekunden
6. **Cache-Write:** Antwort in Redis speichern (TTL 600s)
7. **Response:** JSON an Frontend
8. **Frontend Render:** WeatherCard-Komponente zeigt Daten

## Healthcheck-Strategie

| Endpoint | Probe-Typ | Intervall | Timeout | Zweck |
|----------|-----------|-----------|---------|-------|
| `/health` (Backend) | Startup | 5s | 3s | Initialer Start (max. 50s) |
| `/health` (Backend) | Readiness | 10s | 3s | Traffic erst nach OK |
| `/health` (Backend) | Liveness | 30s | 5s | Container-Restart bei Fehler |
| `/health` (Frontend) | Readiness | 10s | 3s | Nginx-Status |
| `/health` (Frontend) | Liveness | 30s | 3s | Container-Restart |

Backend-Health-Response (Beispiel):

```json
{
  "status": "ok",
  "environment": "prod",
  "redis": "ok",
  "api_key_configured": true
}
```

## Skalierung

| Service | Min | Max | Trigger |
|---------|-----|-----|---------|
| Frontend | 1 | 3 | > 50 gleichzeitige Requests |
| Backend | 1 | 3 | > 30 gleichzeitige Requests |
| Redis | 1 | 1 | (Single Instance) |

In DEV ist `minReplicas: 0` aktiviert → Scale-to-Zero → spart Kosten.

## Logging und Monitoring

- **Strukturierte Logs:** Backend schreibt nach `stdout` im Format
  `<timestamp> [<level>] <logger>: <message>`
- **Application Insights:** Auto-Instrumentation für HTTP-Calls
- **Log Analytics Workspace:** Aggregiert Logs aller Container Apps
- **Custom Metrics:** Cache-HIT/MISS-Rate (geplant für v2)

---

<div align="center">

**Mehmet Ali Gür – HF Informatik**
**Mai 2026**

</div>
