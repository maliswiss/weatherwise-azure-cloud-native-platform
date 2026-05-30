"""
WeatherWise Backend - FastAPI Proxy für OpenWeatherMap.

Verantwortlichkeiten:
- Sichere Verwahrung des OpenWeatherMap API-Keys (nie im Frontend)
- Caching von API-Antworten via Redis (Rate-Limit-Schutz)
- Bereitstellung eines Health-Endpoints für den Container-Orchestrator
- Strukturierte Logs für Monitoring

Author: Mehmet Ali Gür
Modul: Deployment (HF Informatik, Mai 2026)
"""

import json
import logging
import os
import sys
from contextlib import asynccontextmanager

import httpx
import redis.asyncio as redis
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ---------------------------------------------------------------------------
# Konfiguration aus Environment-Variablen
# ---------------------------------------------------------------------------
OPENWEATHER_API_KEY: str | None = os.getenv("OPENWEATHER_API_KEY")
OPENWEATHER_BASE_URL: str = os.getenv(
    "OPENWEATHER_BASE_URL", "https://api.openweathermap.org/data/2.5"
)
REDIS_URL: str = os.getenv("REDIS_URL", "redis://redis:6379/0")
CACHE_TTL_SECONDS: int = int(os.getenv("CACHE_TTL_SECONDS", "600"))  # 10 Minuten
CORS_ORIGINS: list[str] = os.getenv(
    "CORS_ORIGINS", "http://localhost:5173,http://localhost:8080"
).split(",")
APP_ENV: str = os.getenv("APP_ENV", "development")

# ---------------------------------------------------------------------------
# Logging-Konfiguration (strukturiert für Cloud-Logging)
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger("weatherwise")


# ---------------------------------------------------------------------------
# Lifespan: Redis-Verbindung beim Start aufbauen, beim Stop schließen
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialisiert und schließt die Redis-Verbindung."""
    if not OPENWEATHER_API_KEY:
        logger.error("OPENWEATHER_API_KEY ist nicht gesetzt - Backend nicht funktionsfähig")
    else:
        logger.info("Backend startet in Umgebung: %s", APP_ENV)

    app.state.redis = None
    try:
        app.state.redis = redis.from_url(REDIS_URL, decode_responses=True)
        await app.state.redis.ping()
        logger.info("Redis-Verbindung erfolgreich: %s", REDIS_URL.split("@")[-1])
    except Exception as exc:  # noqa: BLE001
        logger.warning("Redis nicht erreichbar (%s) - Caching deaktiviert", exc)
        app.state.redis = None

    yield

    if app.state.redis is not None:
        await app.state.redis.close()
        logger.info("Redis-Verbindung geschlossen")


# ---------------------------------------------------------------------------
# FastAPI-App
# ---------------------------------------------------------------------------
app = FastAPI(
    title="WeatherWise Backend",
    description="Proxy-API für OpenWeatherMap mit Caching",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)

# Default-Wert für app.state.redis vor jeglichem Request setzen
# (wichtig für Tests, wo der Lifespan nicht immer korrekt läuft)
app.state.redis = None


# ---------------------------------------------------------------------------
# Hilfsfunktion: Redis sicher abrufen
# ---------------------------------------------------------------------------
def get_redis() -> redis.Redis | None:
    """
    Gibt die Redis-Verbindung zurück oder None, wenn nicht initialisiert.

    Defensiv gegen fehlenden app.state.redis Attribut (z.B. in Tests).
    """
    return getattr(app.state, "redis", None)


# ---------------------------------------------------------------------------
# Health-Endpoints
# ---------------------------------------------------------------------------
class HealthResponse(BaseModel):
    """Antwort des Health-Endpoints."""

    status: str
    environment: str
    redis: str
    api_key_configured: bool


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health() -> HealthResponse:
    """
    Liveness- und Readiness-Probe.

    Wird vom Container-Orchestrator (Docker, Azure Container Apps)
    regelmäßig aufgerufen, um den Zustand des Services zu prüfen.
    """
    redis_status = "disabled"
    redis_client = get_redis()
    if redis_client is not None:
        try:
            await redis_client.ping()
            redis_status = "ok"
        except Exception:  # noqa: BLE001
            redis_status = "error"

    return HealthResponse(
        status="ok",
        environment=APP_ENV,
        redis=redis_status,
        api_key_configured=bool(OPENWEATHER_API_KEY),
    )


# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------
async def cache_get(key: str) -> dict | None:
    """Liest einen Eintrag aus Redis. Gibt None zurück, wenn nicht vorhanden."""
    redis_client = get_redis()
    if redis_client is None:
        return None
    try:
        raw = await redis_client.get(key)
        if raw:
            logger.info("Cache-HIT: %s", key)
            return json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Cache-Lesefehler (%s): %s", key, exc)
    logger.info("Cache-MISS: %s", key)
    return None


async def cache_set(key: str, value: dict) -> None:
    """Speichert einen Eintrag in Redis mit TTL."""
    redis_client = get_redis()
    if redis_client is None:
        return
    try:
        await redis_client.setex(key, CACHE_TTL_SECONDS, json.dumps(value))
    except Exception as exc:  # noqa: BLE001
        logger.warning("Cache-Schreibfehler (%s): %s", key, exc)


async def fetch_openweather(endpoint: str, params: dict) -> dict:
    """
    Ruft einen Endpoint der OpenWeatherMap-API auf.

    :param endpoint: z. B. "weather" oder "forecast"
    :param params: Query-Parameter ohne API-Key
    :raises HTTPException: bei API-Fehlern
    """
    if not OPENWEATHER_API_KEY:
        raise HTTPException(status_code=503, detail="API-Key nicht konfiguriert")

    full_params = {**params, "appid": OPENWEATHER_API_KEY, "lang": "de"}
    url = f"{OPENWEATHER_BASE_URL}/{endpoint}"

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(url, params=full_params)
        except httpx.RequestError as exc:
            logger.error("Netzwerkfehler bei OpenWeatherMap: %s", exc)
            raise HTTPException(status_code=502, detail="Wetterdienst nicht erreichbar") from exc

    if response.status_code == 404:
        raise HTTPException(status_code=404, detail="Stadt nicht gefunden")
    if response.status_code == 401:
        logger.error("API-Key abgelehnt von OpenWeatherMap")
        raise HTTPException(status_code=503, detail="Wetterdienst-Konfigurationsfehler")
    if response.status_code >= 400:
        raise HTTPException(
            status_code=response.status_code,
            detail="Fehler beim Laden der Wetterdaten",
        )

    return response.json()


# ---------------------------------------------------------------------------
# Weather-Endpoints
# ---------------------------------------------------------------------------
@app.get("/api/weather", tags=["Weather"])
async def get_weather(
    city: str | None = Query(None, min_length=1, max_length=100),
    lat: float | None = Query(None, ge=-90, le=90),
    lon: float | None = Query(None, ge=-180, le=180),
    units: str = Query("metric", pattern="^(metric|imperial)$"),
) -> dict:
    """
    Aktuelle Wetterdaten - entweder per Stadt ODER per Koordinaten.
    """
    if city:
        cache_key = f"weather:city:{city.lower()}:{units}"
        params = {"q": city, "units": units}
    elif lat is not None and lon is not None:
        cache_key = f"weather:coords:{lat:.2f}:{lon:.2f}:{units}"
        params = {"lat": lat, "lon": lon, "units": units}
    else:
        raise HTTPException(
            status_code=400,
            detail="Entweder 'city' oder 'lat' und 'lon' angeben",
        )

    cached = await cache_get(cache_key)
    if cached:
        return cached

    data = await fetch_openweather("weather", params)
    await cache_set(cache_key, data)
    return data


@app.get("/api/forecast", tags=["Weather"])
async def get_forecast(
    city: str = Query(..., min_length=1, max_length=100),
    units: str = Query("metric", pattern="^(metric|imperial)$"),
) -> dict:
    """5-Tages-Vorhersage in 3-Stunden-Intervallen."""
    cache_key = f"forecast:{city.lower()}:{units}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    data = await fetch_openweather("forecast", {"q": city, "units": units})
    await cache_set(cache_key, data)
    return data


# ---------------------------------------------------------------------------
# Root
# ---------------------------------------------------------------------------
@app.get("/", tags=["Info"])
async def root() -> dict:
    """Begrüßungs-Endpoint."""
    return {
        "service": "WeatherWise Backend",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }
