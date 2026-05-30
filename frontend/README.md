# WeatherWise – Frontend

Single Page Application (SPA) für aktuelle Wetterdaten und Vorhersagen,
entwickelt mit React 19, TypeScript und Vite.

> **Hinweis:** Dieser Ordner enthält ausschließlich das Frontend.
> Das vollständige Projekt (Backend, Docker, CI/CD, Deployment) ist im
> Root-Verzeichnis dokumentiert. Siehe `../README.md`.

## Übersicht

WeatherWise ruft Wetterdaten über das eigene Backend ab, das als sicherer
Proxy zur OpenWeatherMap-API dient. Der API-Schlüssel verlässt nie die
Server-Seite.

## Hauptfunktionen

- Stadtsuche und Geolokalisierung
- Aktuelle Wetterdaten mit allen Details
- 5-Tage-Vorhersage
- Stündliche Prognose (nächste 24 Stunden)
- Favoritenverwaltung (LocalStorage)
- Umschaltung Celsius / Fahrenheit
- Responsive Design (Mobile, Tablet, Desktop)

## Technologien

- React 19 + TypeScript
- Vite 8 (Build-Tool)
- React Router (SPA-Routing)
- Zustand (State-Management)
- Lucide React (Icons)

## Lokale Entwicklung (ohne Docker)

```bash
npm install
cp .env.example .env
# In .env: VITE_API_BASE_URL=http://localhost:8000

npm run dev
```

Erreichbar unter http://localhost:5173.

## Mit Docker (empfohlen)

Aus dem Projekt-Root:

```bash
docker compose up
```

Das Frontend ist dann unter http://localhost:8080 erreichbar.

## Autor

Mehmet Ali Gür – HF Informatik – Mai 2026
