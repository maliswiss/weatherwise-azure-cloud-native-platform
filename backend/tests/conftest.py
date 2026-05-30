"""
Pytest-Konfiguration und gemeinsame Fixtures.

Stellt einen TestClient für die FastAPI-Anwendung bereit und mockt
externe Abhängigkeiten (Redis, OpenWeatherMap-API).
"""

import os
from collections.abc import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient

# Test-Environment vor App-Import setzen
os.environ["OPENWEATHER_API_KEY"] = "test-api-key-for-testing"
os.environ["REDIS_URL"] = "redis://localhost:6379/15"  # Test-DB
os.environ["APP_ENV"] = "test"
os.environ["CACHE_TTL_SECONDS"] = "60"

from app.main import app  # noqa: E402  - Import nach Env-Setup


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    """
    Asynchroner HTTP-Client für FastAPI-Tests.

    Tetikt manuell den FastAPI-Lifespan-Context, damit app.state.redis
    korrekt initialisiert wird (ASGITransport macht das nicht automatisch).
    """
    transport = ASGITransport(app=app)
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac
