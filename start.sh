#!/usr/bin/env bash
# =============================================================================
# WeatherWise - Lokales Start-Skript (Linux / macOS)
# =============================================================================
# Erfüllt K9 (Reproduzierbarkeit): Ein Befehl startet alles.
# Aufruf:  ./start.sh
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==> WeatherWise - lokales Setup wird gestartet${NC}"

# .env prüfen
if [ ! -f .env ]; then
    echo -e "${YELLOW}[!] Keine .env-Datei gefunden.${NC}"
    echo -e "${YELLOW}    .env.example wird kopiert - bitte API-Key eintragen!${NC}"
    cp .env.example .env
    echo ""
    echo -e "${YELLOW}    Datei .env öffnen und OPENWEATHER_API_KEY setzen, dann erneut starten.${NC}"
    exit 1
fi

# Docker prüfen
if ! docker version > /dev/null 2>&1; then
    echo -e "${RED}[X] Docker läuft nicht. Bitte Docker Desktop bzw. den Docker-Daemon starten.${NC}"
    exit 1
fi

echo -e "${CYAN}==> Images werden gebaut...${NC}"
docker compose build

echo -e "${CYAN}==> Services werden gestartet...${NC}"
docker compose up -d

echo ""
echo -e "${GREEN}==> WeatherWise läuft!${NC}"
echo "    Frontend:  http://localhost:8080"
echo "    Backend:   http://localhost:8000"
echo "    API-Docs:  http://localhost:8000/docs"
echo "    Health:    http://localhost:8000/health"
echo ""
echo "    Logs ansehen:     docker compose logs -f"
echo "    Services stoppen: docker compose down"
