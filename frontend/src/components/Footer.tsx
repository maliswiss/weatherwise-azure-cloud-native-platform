import { CloudSun } from "lucide-react";

/**
 * Footer-Komponente mit Projektinformationen und Links.
 */
function Footer() {
  return (
    <footer className="footer" role="contentinfo">
      <div className="footer-container">
        <div className="footer-brand">
          <CloudSun size={20} aria-hidden="true" />
          <span>WeatherWise</span>
        </div>
        <p className="footer-text">
          Wetterdaten von{" "}
          <a
            href="https://openweathermap.org/"
            target="_blank"
            rel="noopener noreferrer"
          >
            OpenWeatherMap
          </a>
        </p>
        <p className="footer-copyright">
          &copy; {new Date().getFullYear()} WeatherWise &ndash; Mehmet Ali Gür, HF Informatik, Mai 2026
        </p>
      </div>
    </footer>
  );
}

export default Footer;
