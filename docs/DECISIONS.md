# Architecture Decision Records (ADRs)

Eine kurze Begründung der wichtigsten technischen Entscheidungen.

---

## ADR-001: Backend als Proxy statt direkter Frontend-Call


### Kontext

WeatherWise braucht Wetterdaten von OpenWeatherMap. Die naive Lösung wäre,
den API-Key in einer `VITE_OPENWEATHER_API_KEY`-Umgebungsvariable zu hinterlegen
und das Frontend direkt mit OpenWeatherMap sprechen zu lassen.

### Problem

Vite-Variablen mit `VITE_`-Präfix landen im **Browser-Bundle**. Jeder Besucher
kann den API-Key über die DevTools (Network-Tab oder Sources) auslesen. Damit
wäre der Key effektiv öffentlich, das Rate-Limit könnte missbraucht werden, und
es entstünden Kosten für den Besitzer des Keys.

### Entscheidung

Ein **eigenes FastAPI-Backend** als Proxy. Das Frontend spricht ausschließlich
mit dem eigenen Backend. Der OpenWeatherMap-API-Key wird im Backend in einer
Environment-Variable gehalten, die aus **Azure Key Vault** über
**Managed Identity** geladen wird. Der Key erreicht den Browser zu keinem
Zeitpunkt.

### Zusätzliche Vorteile

Das Backend kann zusätzlich **Caching** mit Redis machen (TTL 10 min). Das
schützt das OpenWeatherMap-Rate-Limit und beschleunigt wiederholte Abfragen
auf < 10 ms.

### Konsequenzen

- (+) Sicherheit: API-Key ist serverseitig geschützt
- (+) Performance: Caching reduziert Latenz
- (+) Mehr Kontrolle: Eigene Fehlerbehandlung, Rate-Limit-Schutz
- (−) Mehr Komplexität: zusätzlicher Service statt rein statischem Frontend
- (−) Zusätzliche Kosten: Backend muss laufen (allerdings dank Scale-to-Zero
  in DEV minimal)

---

## ADR-002: Azure Container Apps statt AKS


### Kontext

Die Aufgabenstellung erlaubt Managed Cloud, Self-Hosted (Coolify) oder
Kubernetes. Innerhalb Azure stehen mehrere Optionen zur Verfügung.

### Optionen

1. **Azure Kubernetes Service (AKS)** — voller K8s-Cluster
2. **Azure Container Apps (ACA)** — Managed-Kubernetes-Layer
3. **Azure App Service for Containers** — sehr einfach, aber unflexibel
4. **Azure Container Instances** — Single-Container, kein Multi-Service

### Entscheidung

**Azure Container Apps (ACA)**.

### Begründung

| Kriterium | ACA | AKS |
|-----------|-----|-----|
| Setup-Zeit | 1-2 Stunden | 1-2 Tage |
| Control-Plane-Kosten | 0 CHF/Monat | ca. 70 CHF/Monat |
| Geeignet für kleine Projekte | ✓ | × (hohe Betriebskosten) |
| Probes (Liveness/Readiness/Startup) | ✓ | ✓ |
| Rolling Update | automatisch | konfigurierbar |
| HTTPS automatisch | ✓ | manuell (Ingress + cert-manager) |
| Scale-to-Zero | ✓ (DEV) | ja (mit KEDA) |
| Managed Identity | nativ | nativ |
| Lernkurve | flach | steil |

ACA basiert intern auf **Kubernetes** (managed). Das heißt, wir profitieren
von K8s-Konzepten (Probes, Replicas, Rolling Update) ohne den operativen
Overhead einer eigenen Cluster-Verwaltung.

### Konsequenzen

- (+) Schneller produktiv
- (+) Niedrige Kosten
- (+) Sehr gute Azure-Integration (ACR, Key Vault, App Insights)
- (−) Weniger Kontrolle über Networking-Details
- (−) Kein direkter Zugriff auf Nodes
- (−) Einige K8s-Features (DaemonSets, StatefulSets) nicht verfügbar

---

## ADR-003: Bicep statt Terraform


### Kontext

Infrastructure as Code ist eine der "erweiterten Anforderungen" der Aufgabe.

### Optionen

1. **Bicep** — Azure-natives DSL
2. **Terraform** — Cloud-agnostisch
3. **Pulumi** — Programmiersprachen statt DSL
4. **ARM-Templates** — Bicep's Vorgänger

### Entscheidung

**Bicep**.

### Begründung

- **Azure-only Projekt** → keine Multi-Cloud-Vorteile von Terraform nötig
- **Kein State-Backend nötig** (Azure verwaltet den Deployment-Status selbst)
- **Direkt von Microsoft gepflegt** → schnelle Updates für neue Azure-Features
- **Bessere IDE-Integration** (IntelliSense in VS Code mit Bicep-Extension)
- **Kürzere Syntax** als ARM-Templates

### Konsequenzen

- (+) Wartungsärmer als ARM
- (+) Schnelleres Onboarding für neue Entwickler
- (−) Nicht portabel auf andere Cloud-Anbieter

---

## ADR-004: Managed Identity statt Service Principal


### Kontext

Das Backend braucht Lesezugriff auf den Key Vault, um den OpenWeatherMap-Key
abzurufen.

### Optionen

1. **Service Principal mit Secret** in Env-Variable
2. **Managed Identity** (User-Assigned)
3. **Connection String** mit Account-Key

### Entscheidung

**User-Assigned Managed Identity**.

### Begründung

| Vorteil | Erklärung |
|---------|-----------|
| Keine Credentials zu rotieren | Azure verwaltet Tokens automatisch |
| Keine Secrets in Env-Variablen | Tokens kommen aus dem IMDS-Endpoint |
| Audit-Trail in Azure AD | Jeder Secret-Zugriff ist protokolliert |
| Least-Privilege | Nur "Key Vault Secrets User" Rolle nötig |
| Bewährter Standard | Microsoft empfiehlt Managed Identity |

User-Assigned (statt System-Assigned), damit die Identity beim Container-App-
Replace nicht verloren geht und mehrere Apps dieselbe Identity teilen können.

### Konsequenzen

- (+) Keine Geheimnisse in Code oder Env-Variablen
- (+) Einfache RBAC-Verwaltung
- (−) Funktioniert nur innerhalb Azure (nicht für lokales Entwickeln)

Für lokale Entwicklung wird die `.env`-Datei genutzt (siehe `.env.example`).

---

## ADR-005: GitHub Actions statt GitLab CI


### Kontext

Das Projekt brauchte eine CI/CD-Plattform.

### Entscheidung

**GitHub Actions** auf einem öffentlichen GitHub-Repository.

### Begründung

- **Kostenlos** für Public Repos
- **Exzellente Azure-Integration** (offizielle `azure/login@v2`-Action)
- **Marketplace** mit Actions für Trivy, Docker, Bicep
- **Native GitHub Security Tab** für SARIF-Reports von Trivy
- **Dependabot** out-of-the-box (Security-Updates)

GitLab CI wäre ebenfalls möglich, GIBB nutzt es intern. Aber:

- GitHub ist die Plattform der Open-Source-Community
- Mehr Beispiele und Tutorials online
- Bessere Sichtbarkeit des Projekts für Bewerbungen

### Konsequenzen

- (+) Niedrige Einstiegshürde
- (+) Hervorragende Dokumentation
- (+) Security-Features (Dependabot, CodeQL, SARIF) inklusive
- (−) GitLab-spezifische Features (Auto-DevOps, Container Registry) entfallen

---

## ADR-006: Multi-Stage Dockerfile + Non-Root + Alpine


### Kontext

Die Container-Images sollten klein, sicher und reproduzierbar sein.

### Entscheidung

Für jedes Image:

1. **Multi-Stage Build** mit `builder` + `runtime` Stages
2. **Alpine-Basis** (Python: `python:3.12-slim`, Frontend: `nginx:1.27-alpine`)
3. **Non-Root User** (UID 1001 für Backend, eingebauter `nginx`-User für Frontend)
4. **OCI-Labels** für Image-Metadaten
5. **Healthcheck** im Dockerfile selbst

### Ergebnis

| Image | Endgröße |
|-------|----------|
| Backend (FastAPI + Python 3.12) | ca. 180 MB |
| Frontend (Nginx + Vite-Build) | ca. 50 MB |

### Konsequenzen

- (+) Schnellere Image-Downloads → schnellere Deploys
- (+) Geringere Angriffsfläche durch kleines Image
- (+) Kein Root-Privilege im Container
- (−) Mehrere Stages verlängern den Build um wenige Sekunden
- (−) Alpine hat manchmal Probleme mit Native-Dependencies (für uns nicht relevant)

---

<div align="center">

**Mehmet Ali Gür – HF Informatik**
**Mai 2026**

</div>
