"""
Tests für die WeatherWise-Backend-Endpoints.

Abdeckung:
- /health: Liveness- und Readiness-Probe
- /: Root-Endpoint mit Service-Info
- /api/weather: Aktuelle Wetterdaten (Stadt + Koordinaten)
- /api/forecast: 5-Tages-Vorhersage
- Fehlerbehandlung (404, 503, ungültige Parameter)
"""

import httpx
import respx
from httpx import AsyncClient

# ---------------------------------------------------------------------------
# Test-Daten (Mock-Antworten von OpenWeatherMap)
# ---------------------------------------------------------------------------
MOCK_WEATHER_RESPONSE = {
    "name": "Bern",
    "sys": {"country": "CH", "sunrise": 1716955200, "sunset": 1717009200},
    "main": {
        "temp": 18.5,
        "feels_like": 17.8,
        "humidity": 65,
        "pressure": 1015,
    },
    "weather": [{"description": "klarer Himmel", "icon": "01d"}],
    "wind": {"speed": 2.5, "deg": 180},
    "visibility": 10000,
    "clouds": {"all": 5},
    "coord": {"lat": 46.948, "lon": 7.4474},
    "dt": 1716980000,
}

MOCK_FORECAST_RESPONSE = {
    "list": [
        {
            "dt_txt": f"2026-05-{day:02d} 12:00:00",
            "main": {"temp": 20.0, "temp_min": 15.0, "temp_max": 22.0, "humidity": 60},
            "weather": [{"description": "sonnig", "icon": "01d"}],
            "wind": {"speed": 3.0},
            "pop": 0.1,
        }
        for day in range(25, 30)
    ]
}


# ===========================================================================
# Health-Endpoint
# ===========================================================================
class TestHealthEndpoint:
    """Tests für /health - kritisch für Container-Orchestrator."""

    async def test_health_returns_200(self, client: AsyncClient) -> None:
        """Health-Endpoint muss immer 200 zurückgeben."""
        response = await client.get("/health")
        assert response.status_code == 200

    async def test_health_contains_status(self, client: AsyncClient) -> None:
        """Health-Antwort muss 'status: ok' enthalten."""
        response = await client.get("/health")
        data = response.json()
        assert data["status"] == "ok"

    async def test_health_contains_environment(self, client: AsyncClient) -> None:
        """Health-Antwort muss die aktuelle Umgebung melden."""
        response = await client.get("/health")
        data = response.json()
        assert "environment" in data
        assert data["environment"] == "test"

    async def test_health_reports_api_key_configured(self, client: AsyncClient) -> None:
        """Health-Endpoint muss melden, ob ein API-Key gesetzt ist."""
        response = await client.get("/health")
        data = response.json()
        assert "api_key_configured" in data
        assert data["api_key_configured"] is True


# ===========================================================================
# Root-Endpoint
# ===========================================================================
class TestRootEndpoint:
    """Tests für / - Service-Discovery."""

    async def test_root_returns_service_info(self, client: AsyncClient) -> None:
        """Root muss Service-Namen und Version liefern."""
        response = await client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["service"] == "WeatherWise Backend"
        assert "version" in data

    async def test_root_contains_docs_link(self, client: AsyncClient) -> None:
        """Root muss auf die OpenAPI-Dokumentation verweisen."""
        response = await client.get("/")
        data = response.json()
        assert data["docs"] == "/docs"


# ===========================================================================
# Weather-Endpoint
# ===========================================================================
class TestWeatherEndpoint:
    """Tests für /api/weather - Hauptfunktion."""

    @respx.mock
    async def test_weather_by_city_returns_data(self, client: AsyncClient) -> None:
        """Stadt-Abfrage muss korrekte Wetterdaten zurückgeben."""
        respx.get("https://api.openweathermap.org/data/2.5/weather").mock(
            return_value=httpx.Response(200, json=MOCK_WEATHER_RESPONSE)
        )

        response = await client.get("/api/weather?city=Bern")
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Bern"
        assert data["sys"]["country"] == "CH"

    @respx.mock
    async def test_weather_by_coords_returns_data(self, client: AsyncClient) -> None:
        """Koordinaten-Abfrage muss funktionieren."""
        respx.get("https://api.openweathermap.org/data/2.5/weather").mock(
            return_value=httpx.Response(200, json=MOCK_WEATHER_RESPONSE)
        )

        response = await client.get("/api/weather?lat=46.948&lon=7.4474")
        assert response.status_code == 200

    async def test_weather_without_params_returns_400(self, client: AsyncClient) -> None:
        """Weder city noch coords angegeben - 400 erwartet."""
        response = await client.get("/api/weather")
        assert response.status_code == 400

    async def test_weather_invalid_lat_returns_422(self, client: AsyncClient) -> None:
        """Ungültige Latitude (>90) muss 422 zurückgeben."""
        response = await client.get("/api/weather?lat=999&lon=0")
        assert response.status_code == 422

    @respx.mock
    async def test_weather_city_not_found_returns_404(self, client: AsyncClient) -> None:
        """Stadt, die nicht existiert, muss 404 ergeben."""
        respx.get("https://api.openweathermap.org/data/2.5/weather").mock(
            return_value=httpx.Response(404, json={"message": "city not found"})
        )

        response = await client.get("/api/weather?city=NichtExistierendeStadt12345")
        assert response.status_code == 404


# ===========================================================================
# Forecast-Endpoint
# ===========================================================================
class TestForecastEndpoint:
    """Tests für /api/forecast - 5-Tages-Vorhersage."""

    @respx.mock
    async def test_forecast_returns_data(self, client: AsyncClient) -> None:
        """Forecast-Abfrage muss eine Liste zurückgeben."""
        respx.get("https://api.openweathermap.org/data/2.5/forecast").mock(
            return_value=httpx.Response(200, json=MOCK_FORECAST_RESPONSE)
        )

        response = await client.get("/api/forecast?city=Bern")
        assert response.status_code == 200
        data = response.json()
        assert "list" in data
        assert len(data["list"]) == 5

    async def test_forecast_without_city_returns_422(self, client: AsyncClient) -> None:
        """Forecast ohne city-Parameter muss 422 ergeben."""
        response = await client.get("/api/forecast")
        assert response.status_code == 422

    async def test_forecast_invalid_units_returns_422(self, client: AsyncClient) -> None:
        """Ungültige Einheit (weder metric noch imperial) - 422."""
        response = await client.get("/api/forecast?city=Bern&units=ungueltig")
        assert response.status_code == 422


# ===========================================================================
# Sicherheits-Tests
# ===========================================================================
class TestSecurity:
    """Sicherheits-relevante Tests."""

    async def test_api_key_not_in_response_headers(self, client: AsyncClient) -> None:
        """API-Key darf NIE in Response-Headers auftauchen."""
        response = await client.get("/health")
        for header_value in response.headers.values():
            assert "test-api-key" not in header_value.lower()

    async def test_api_key_not_in_root_response(self, client: AsyncClient) -> None:
        """API-Key darf NIE im Root-Response erscheinen."""
        response = await client.get("/")
        assert "test-api-key" not in response.text
        assert "OPENWEATHER_API_KEY" not in response.text
