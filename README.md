# Geospatial Routing API

A **free, self-hosted** geospatial routing service for computing distances, travel times, and directions. Built as a lightweight alternative to paid services like Google Maps API or Mapbox for local development and testing.

## Tech Stack

- **OSRM** (Open Source Routing Machine) - High-performance routing engine
- **Flask** - Python API wrapper
- **Docker** - Containerized deployment

## Features

| Endpoint | Description |
|----------|-------------|
| `/nearest` | Find the nearest road to a coordinate |
| `/route` | Get turn-by-turn driving directions |
| `/matrix` | Distance/duration matrix between multiple points |
| `/match` | Snap GPS traces to roads (map matching) |
| `/health` | Health check for container orchestration |

---

## Quick Start

### Prerequisites

- Docker installed and running
- Node.js (for frontend)
- OSRM data files in `./data/` folder (see [Data Setup](#data-setup))

### Start Everything (Backend + Frontend)

**Mac/Linux:** from the repo root, with Docker running and OSRM `*.osrm` files in `./data/`:

```bash
chmod +x scripts/local/start-all.sh scripts/local/stop-all.sh
./scripts/local/start-all.sh
```

This builds and runs the combined OSRM + Flask container on [http://127.0.0.1:8080](http://127.0.0.1:8080). Start the Next.js UI in another terminal:

```bash
cd frontend && npm install && npm run dev
```

Demos in sibling repos (`VRP`, `ResponderDispatch`) expect the API at `http://127.0.0.1:8080` unless you set `GEOSPATIAL_URL` there.

### Test the Service

```
GET http://localhost:8080/health
→ {"status": "healthy"}
```

### Stop the Service

```bash
./scripts/local/stop-all.sh
```

Stop the dev frontend with `Ctrl+C` in its terminal.

---

## Data Setup

OSRM requires preprocessed map data.

<details>
<summary>Setup Instructions</summary>

### 1. Download OpenStreetMap data

Download a `.osm.pbf` file from [Geofabrik](https://download.geofabrik.de/).

### 2. Preprocess with OSRM

```bash
mkdir -p data
cd data

# Extract
docker run -v $(pwd):/data osrm/osrm-backend osrm-extract -p /opt/car.lua /data/YOUR_FILE.osm.pbf

# Partition
docker run -v $(pwd):/data osrm/osrm-backend osrm-partition /data/YOUR_FILE.osrm

# Customize
docker run -v $(pwd):/data osrm/osrm-backend osrm-customize /data/YOUR_FILE.osrm
```

This creates ~30 `.osrm*` files in your data directory.
</details>

---

## Python Client Example

<details>
<summary>Show Example</summary>

```python
import requests

API = "http://localhost:8080"

# Distance matrix
resp = requests.post(f"{API}/matrix", json={
    "coordinates": [
        [-123.1207, 49.2827],
        [-123.1162, 49.2463],
        [-122.8490, 49.1913],
    ]
})
print(resp.json())

# Driving directions
resp = requests.post(f"{API}/route", json={
    "coordinates": [
        [-123.1207, 49.2827],
        [-122.8490, 49.1913]
    ],
    "steps": True
})
print(resp.json())
```
</details>

---

## Why Use This?

| Feature | Google Maps API | This Project |
|---------|-----------------|--------------|
| Cost | $5-10 per 1000 requests | Free |
| Privacy | Data sent to Google | Runs locally |
| Rate limits | Yes | No |
| Offline | No | Yes |

---

## Advanced: Kubernetes Deployment

See [README-K8S.md](README-K8S.md).

---

## Frontend (Web UI)

A Next.js web interface for testing the API with interactive map visualization.

```bash
cd frontend
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). Features:
- Dropdown to switch between `/nearest`, `/route`, `/matrix`, `/match`
- Live health check indicator (polls every 30s)
- Leaflet map to visualize results
- JSON response viewer
- Parameter documentation for each endpoint

---

## API Reference

All endpoints use `POST` with JSON body. Coordinates are `[longitude, latitude]`.

---

### `POST /nearest`

Find the nearest road to a coordinate.

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `coordinate` | `[lon, lat]` | Yes | Point to search from |
| `number` | `int` | No | Number of results (default: 1) |

**Response:**
| Field | Description |
|-------|-------------|
| `waypoints[].name` | Street name |
| `waypoints[].location` | Snapped `[lon, lat]` on road |
| `waypoints[].distance` | Distance from input to road (meters) |

---

### `POST /route`

Get driving directions between points.

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `coordinates` | `[[lon, lat], ...]` | Yes | 2+ points |
| `steps` | `bool` | No | Include turn-by-turn instructions |
| `geometries` | `string` | No | `"polyline"`, `"polyline6"`, or `"geojson"` |
| `overview` | `string` | No | `"full"`, `"simplified"`, or `"false"` |

**Response:**
| Field | Description |
|-------|-------------|
| `routes[].distance` | Total distance (meters) |
| `routes[].duration` | Total time (seconds) |
| `routes[].geometry` | Route line |
| `routes[].legs[].steps[]` | Turn-by-turn instructions (if requested) |

---

### `POST /matrix`

Get distance/duration matrix between all coordinate pairs.

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `coordinates` | `[[lon, lat], ...]` | Yes | List of points |

**Response:**
| Field | Description |
|-------|-------------|
| `distance_matrix` | NxN matrix of distances (meters) |
| `duration_matrix` | NxN matrix of durations (seconds) |

`matrix[i][j]` = value from point `i` to point `j`

---

### `POST /match`

Snap GPS trace to roads (map matching).

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `coordinates` | `[[lon, lat], ...]` | Yes | GPS points in order |
| `timestamps` | `[int, ...]` | No | Unix timestamps per point |
| `radiuses` | `[int, ...]` | No | GPS accuracy (meters) per point |
| `geometries` | `string` | No | `"polyline"`, `"polyline6"`, or `"geojson"` |

**Response:**
| Field | Description |
|-------|-------------|
| `matchings[].confidence` | Match quality (0-1) |
| `matchings[].distance` | Road distance (meters) |
| `matchings[].duration` | Travel time (seconds) |
| `matchings[].geometry` | Snapped route line |
| `tracepoints[].name` | Street name |
| `tracepoints[].location` | Snapped `[lon, lat]` |

---

### `GET /health`

Health check.

**Response:** `{"status": "healthy"}`

---

## License

MIT
