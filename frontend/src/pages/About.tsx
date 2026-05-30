import { useEffect } from "react";
import { Info, User, Code, Database, Globe, Calendar } from "lucide-react";

/**
 * Info-Seite: Zeigt Informationen über das Projekt und die Technologien.
 */
function About() {
  useEffect(() => {
    document.title = "Info – WeatherWise";
  }, []);

  return (
    <div className="page page-about">
      <div className="page-header">
        <Info size={28} aria-hidden="true" />
        <h1>Über WeatherWise</h1>
      </div>

      <section className="about-section">
        <h2>
          <Globe size={22} aria-hidden="true" />
          Projektbeschreibung
        </h2>
        <p>
          WeatherWise ist eine moderne Wetter-Web-Applikation, die aktuelle
          Wetterdaten und mehrtägige Vorhersagen für beliebige Städte weltweit
          bereitstellt. Die Anwendung ist als Single Page Application mit
          React und TypeScript umgesetzt und wird über eine eigene Backend-API
          mit Caching und sicherer Schlüsselverwaltung bedient.
        </p>
        <p>
          Im Rahmen des Moduls Deployment wurde die Applikation
          containerisiert, mit einer CI/CD-Pipeline versehen und produktionsreif
          in der Cloud bereitgestellt.
        </p>
      </section>

      <section className="about-section">
        <h2>
          <User size={22} aria-hidden="true" />
          Autor
        </h2>
        <div className="author-info">
          <h3>Mehmet Ali Gür</h3>
          <p>HF Informatik</p>
          <p className="author-meta">
            <Calendar size={16} aria-hidden="true" />
            <span>Mai 2026</span>
          </p>
        </div>
      </section>

      <section className="about-section">
        <h2>
          <Code size={22} aria-hidden="true" />
          Technologien
        </h2>
        <div className="tech-grid">
          <div className="tech-card">
            <h3>React 19</h3>
            <p>Komponentenbasierte UI-Bibliothek</p>
          </div>
          <div className="tech-card">
            <h3>TypeScript</h3>
            <p>Typsichere Programmierung</p>
          </div>
          <div className="tech-card">
            <h3>Vite</h3>
            <p>Schnelles Build-Tool und Dev-Server</p>
          </div>
          <div className="tech-card">
            <h3>FastAPI</h3>
            <p>Backend-Proxy mit Caching</p>
          </div>
          <div className="tech-card">
            <h3>Redis</h3>
            <p>In-Memory-Cache für API-Antworten</p>
          </div>
          <div className="tech-card">
            <h3>Docker</h3>
            <p>Containerisierung aller Services</p>
          </div>
        </div>
      </section>

      <section className="about-section">
        <h2>
          <Database size={22} aria-hidden="true" />
          Datenquelle
        </h2>
        <p>
          Alle Wetterdaten werden von der{" "}
          <a
            href="https://openweathermap.org/api"
            target="_blank"
            rel="noopener noreferrer"
          >
            OpenWeatherMap API
          </a>{" "}
          bezogen. Die API bietet aktuelle Wetterdaten, 5-Tage-Vorhersagen und
          stündliche Prognosen für über 200'000 Städte weltweit. Anfragen
          laufen über das eigene Backend, sodass der API-Schlüssel nie im
          Browser erscheint.
        </p>
      </section>
    </div>
  );
}

export default About;
