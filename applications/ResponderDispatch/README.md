# Nearest Responder Sidecar

Local demo that picks the fastest driving responder to an incident using the Geospatial API.

This directory lives inside the Geospatial repo: `applications/ResponderDispatch`.

## Architecture

- **Geospatial** (parent repo root): OSRM-backed Flask API (`/nearest`, `/route`, …).
- **ResponderDispatch** (this folder): dispatch logic and a small Leaflet UI on port **8100**.

The sidecar calls Geospatial at **`GEOSPATIAL_URL`** (default `http://127.0.0.1:8080`). Override if the API is elsewhere, for example in Docker:

```bash
export GEOSPATIAL_URL=http://host.docker.internal:8080
```

## What it does

1. Five responder positions and one incident (defaults or randomized in the UI).
2. Server snaps every point to the road network with Geospatial `POST /nearest`, then requests `POST /route` for each responder to the snapped incident.
3. Ranks by driving `duration` and returns the winner plus map geometries.

## Run locally

1. Start Geospatial with BC (or compatible) OSRM data so `/nearest` and `/route` succeed.
2. From **this folder**:

```bash
chmod +x ./start.sh
./start.sh
```

Or from the **Geospatial repo root**:

```bash
cd applications/ResponderDispatch && ./start.sh
```

3. Open [http://localhost:8100/](http://localhost:8100/).

Use **Generate simulation** for five random BC points plus a random incident, then dispatch. **Run dispatch** re-runs with the coordinates currently in the form.

## API

- `GET /defaults` — default responders and incident.
- `POST /dispatch/nearest` — nearest-responder decision (JSON body: optional `responders`, `event`, `metric`).
- `GET /health` — process health (does not probe Geospatial).
