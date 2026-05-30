# =============================================================================
# WeatherWise Backend - Multi-Stage Dockerfile
# Erfüllt Bewertungskriterien K1 (Multi-Stage, Non-Root) und K8 (Security)
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Builder - installiert Abhängigkeiten in ein virtuelles Environment
# -----------------------------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /build

# Pip in der neuesten Version, dann Abhängigkeiten in /opt/venv installieren
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


# -----------------------------------------------------------------------------
# Stage 2: Runtime - schlankes Image ohne Build-Tools, mit Non-Root-User
# -----------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

# OCI-Labels für Image-Metadaten
LABEL org.opencontainers.image.title="WeatherWise Backend"
LABEL org.opencontainers.image.description="FastAPI-Proxy für OpenWeatherMap mit Redis-Cache"
LABEL org.opencontainers.image.authors="Mehmet Ali Gür"
LABEL org.opencontainers.image.source="https://github.com/maliswiss/weatherwise-azure-cloud-native-platform"

# Security: Non-Root-User anlegen (UID/GID 1001)
RUN groupadd --system --gid 1001 appgroup && \
    useradd --system --uid 1001 --gid appgroup --home /home/appuser --create-home appuser

# Virtuelles Environment aus dem Builder kopieren
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Curl für den Healthcheck (sehr klein, ~250 KB)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl=* && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Applikationscode kopieren - mit korrektem Owner
COPY --chown=appuser:appgroup app/ ./app/

# Auf Non-Root wechseln
USER appuser

EXPOSE 8000

# Healthcheck: Container ist nur gesund, wenn /health 200 zurückliefert
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl --fail --silent http://localhost:8000/health || exit 1

# Uvicorn mit Produktions-Settings starten
CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "2", \
     "--access-log", \
     "--log-level", "info"]
