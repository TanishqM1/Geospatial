# VRP Sidecar Demo

FastAPI app that uses Google OR-Tools for a round-trip TSP through BC points. It reads travel times or distances from the Geospatial API (`/matrix`, `/route`) and serves a small UI on port **8000**.

This directory lives inside the Geospatial repo: `applications/VRP`.

## Quick start

1. Start Geospatial (API on port 8080), e.g. from the repo root: `./scripts/local/start-all.sh` (or only Docker if you prefer).
2. Start this sidecar from **this folder**:

```bash
cd applications/VRP
chmod +x ./start.sh
./start.sh
```

Or from the **Geospatial repo root**:

```bash
cd applications/VRP && ./start.sh
```

Open [http://localhost:8000/](http://localhost:8000/) and use **Solve + Draw Route** (or the static page under `/static/`).

## What the demo shows

- Named BC locations with coordinates
- Start/depot point
- Traversal order including return to the start
- Per-leg polylines from Geospatial `/route`

## Endpoints

- `POST /solve/tsp` — solve order with OR-Tools
- `POST /solve/tsp_with_routes` — solve and fetch GeoJSON legs
- `GET /health` — health check

## Configuration

- Set **`GEOSPATIAL_URL`** (default `http://127.0.0.1:8080`) if the Flask API is not on localhost.
- `start.sh` uses `--reload` for local development.
