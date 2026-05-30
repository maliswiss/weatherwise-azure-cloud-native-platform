# =============================================================================
# WeatherWise Frontend - Multi-Stage Dockerfile
# Erfüllt Bewertungskriterien K1 (Multi-Stage, Non-Root) und K8 (Security)
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Builder - kompiliert die React-App zu statischen Dateien
# -----------------------------------------------------------------------------
FROM node:22-alpine AS builder

WORKDIR /build

# Dependencies separat installieren - Docker-Layer-Caching
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund

# Quellcode kopieren und bauen
COPY . .

# VITE_API_BASE_URL kommt zur Build-Zeit über ARG / Build-Arg
# Default: localhost - in CI/CD wird es überschrieben
ARG VITE_API_BASE_URL=http://localhost:8000
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

RUN npm run build


# -----------------------------------------------------------------------------
# Stage 2: Runtime - schlanker Nginx-Container, Non-Root auf Port 8080
# -----------------------------------------------------------------------------
FROM nginx:1.27-alpine AS runtime

LABEL org.opencontainers.image.title="WeatherWise Frontend"
LABEL org.opencontainers.image.description="React-SPA für Wetterdaten"
LABEL org.opencontainers.image.authors="Mehmet Ali Gür"
LABEL org.opencontainers.image.source="https://github.com/maliswiss/weatherwise-azure-cloud-native-platform"

# Custom Nginx-Config kopieren
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN rm -f /etc/nginx/conf.d/default.conf.dpkg-dist

# Build-Output aus dem Builder-Stage übernehmen
COPY --from=builder /build/dist /usr/share/nginx/html

# -------------------------------------------------------------------------
# Non-Root: Nginx als unprivilegierter User starten
# Das nginx-Alpine-Image enthält bereits einen 'nginx'-User
# -------------------------------------------------------------------------
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 8080

# Healthcheck über den definierten /health-Endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
