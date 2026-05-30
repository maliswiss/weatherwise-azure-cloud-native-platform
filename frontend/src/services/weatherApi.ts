import type { ForecastDay, HourlyForecast, WeatherData } from "../types/weather";

/**
 * Frontend-Service für Wetterdaten.
 *
 * WICHTIG: Diese Datei spricht ausschließlich mit dem eigenen Backend.
 * Der OpenWeatherMap-API-Key liegt sicher im Backend (Azure Key Vault)
 * und ist im Browser zu keinem Zeitpunkt sichtbar.
 *
 * Die Backend-URL kommt aus der Build-Zeit-Variable VITE_API_BASE_URL.
 * Default für lokale Entwicklung: http://localhost:8000
 */
const API_BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string | undefined) ??
  "http://localhost:8000";

/**
 * Wirft einen sprechenden Fehler, wenn die Antwort nicht OK ist.
 */
async function handleResponse(response: Response): Promise<unknown> {
  if (!response.ok) {
    let message = "Fehler beim Laden der Wetterdaten";
    try {
      const errorData = (await response.json()) as { detail?: string };
      if (errorData.detail) {
        message = errorData.detail;
      }
    } catch {
      // Antwort war kein JSON - Default-Message verwenden
    }
    throw new Error(message);
  }
  return response.json();
}

/**
 * Holt die aktuellen Wetterdaten für eine Stadt.
 */
export async function getCurrentWeather(
  city: string,
  units: string = "metric"
): Promise<WeatherData> {
  const response = await fetch(
    `${API_BASE_URL}/api/weather?city=${encodeURIComponent(city)}&units=${units}`
  );

  const data = (await handleResponse(response)) as {
    name: string;
    sys: { country: string; sunrise: number; sunset: number };
    main: { temp: number; feels_like: number; humidity: number; pressure: number };
    weather: { description: string; icon: string }[];
    wind: { speed: number; deg?: number };
    visibility: number;
    clouds: { all: number };
    coord: { lat: number; lon: number };
    dt: number;
  };

  return {
    city: data.name,
    country: data.sys.country,
    temperature: Math.round(data.main.temp),
    feelsLike: Math.round(data.main.feels_like),
    description: data.weather[0].description,
    icon: data.weather[0].icon,
    humidity: data.main.humidity,
    windSpeed: data.wind.speed,
    windDeg: data.wind.deg ?? 0,
    pressure: data.main.pressure,
    visibility: data.visibility,
    clouds: data.clouds.all,
    sunrise: data.sys.sunrise,
    sunset: data.sys.sunset,
    lat: data.coord.lat,
    lon: data.coord.lon,
    dt: data.dt,
  };
}

/**
 * Holt die aktuellen Wetterdaten anhand von Geokoordinaten.
 */
export async function getWeatherByCoords(
  lat: number,
  lon: number,
  units: string = "metric"
): Promise<WeatherData> {
  const response = await fetch(
    `${API_BASE_URL}/api/weather?lat=${lat}&lon=${lon}&units=${units}`
  );

  const data = (await handleResponse(response)) as {
    name: string;
    sys: { country: string; sunrise: number; sunset: number };
    main: { temp: number; feels_like: number; humidity: number; pressure: number };
    weather: { description: string; icon: string }[];
    wind: { speed: number; deg?: number };
    visibility: number;
    clouds: { all: number };
    coord: { lat: number; lon: number };
    dt: number;
  };

  return {
    city: data.name,
    country: data.sys.country,
    temperature: Math.round(data.main.temp),
    feelsLike: Math.round(data.main.feels_like),
    description: data.weather[0].description,
    icon: data.weather[0].icon,
    humidity: data.main.humidity,
    windSpeed: data.wind.speed,
    windDeg: data.wind.deg ?? 0,
    pressure: data.main.pressure,
    visibility: data.visibility,
    clouds: data.clouds.all,
    sunrise: data.sys.sunrise,
    sunset: data.sys.sunset,
    lat: data.coord.lat,
    lon: data.coord.lon,
    dt: data.dt,
  };
}

/**
 * Holt die 5-Tage-Vorhersage (Mittagswerte) für eine Stadt.
 */
export async function getForecast(
  city: string,
  units: string = "metric"
): Promise<ForecastDay[]> {
  const response = await fetch(
    `${API_BASE_URL}/api/forecast?city=${encodeURIComponent(city)}&units=${units}`
  );

  const data = (await handleResponse(response)) as {
    list: {
      dt_txt: string;
      main: { temp: number; temp_min: number; temp_max: number; humidity: number };
      weather: { description: string; icon: string }[];
      wind: { speed: number };
      pop: number;
    }[];
  };

  const forecastList = data.list
    .filter((item) => item.dt_txt.includes("12:00:00"))
    .slice(0, 5);

  return forecastList.map((item) => ({
    date: item.dt_txt,
    tempMin: Math.round(item.main.temp_min),
    tempMax: Math.round(item.main.temp_max),
    temperature: Math.round(item.main.temp),
    description: item.weather[0].description,
    icon: item.weather[0].icon,
    humidity: item.main.humidity,
    windSpeed: item.wind.speed,
    pop: Math.round(item.pop * 100),
  }));
}

/**
 * Holt die stündliche Vorhersage (nächste 24 Stunden).
 */
export async function getHourlyForecast(
  city: string,
  units: string = "metric"
): Promise<HourlyForecast[]> {
  const response = await fetch(
    `${API_BASE_URL}/api/forecast?city=${encodeURIComponent(city)}&units=${units}`
  );

  const data = (await handleResponse(response)) as {
    list: {
      dt_txt: string;
      main: { temp: number };
      weather: { description: string; icon: string }[];
      pop: number;
    }[];
  };

  return data.list.slice(0, 8).map((item) => ({
    time: item.dt_txt,
    temperature: Math.round(item.main.temp),
    description: item.weather[0].description,
    icon: item.weather[0].icon,
    pop: Math.round(item.pop * 100),
  }));
}

/**
 * Gibt die URL für ein Wettericon zurück.
 * Icons werden direkt von OpenWeatherMap geladen (keine sensitiven Daten).
 */
export function getWeatherIconUrl(iconCode: string): string {
  return `https://openweathermap.org/img/wn/${iconCode}@2x.png`;
}
