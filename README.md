# Geospatial Routing API

A **free, self-hosted** geospatial routing service for computing distances, travel times, directions, and route optimization. Built as a lightweight alternative to paid services like Google Maps API or Mapbox for local development and testing.

## Tech Stack

- **OSRM** (Open Source Routing Machine) - High-performance routing engine
- **Flask** - Python API wrapper
- **Docker** / **Kubernetes** - Containerized deployment

## Features

| Endpoint | Description |
|----------|-------------|
| `/nearest` | Find the nearest road to a coordinate |
| `/route` | Get turn-by-turn driving directions |
| `/matrix` | Distance/duration matrix between multiple points |
| `/trip` | Traveling Salesman Problem solver (optimal visit order) |
| `/match` | Snap GPS traces to roads (map matching) |
| `/health` | Health check for container orchestration |

---

## Quick Start

### Prerequisites

- Docker installed
- OSRM data files for your region (see [Data Setup](#data-setup))

### Run with Docker

```bash
# Build and run
docker build -t geospatial:latest .
docker run -d -p 8080:8080 -v /path/to/data:/data geospatial:latest

# Test
curl -X POST http://localhost:8080/health
```

---

## API Reference

All endpoints accept **POST** requests with JSON body. Coordinates are `[longitude, latitude]` format.

### 1. Nearest

Find the nearest road/point to a coordinate.

**Request:**
```bash
curl -X POST http://localhost:8080/nearest \
  -H "Content-Type: application/json" \
  -d '{
    "coordinate": [-123.1207, 49.2827],
    "number": 1
  }'
```

**Response:**
```json
{
  "waypoints": [
    {
      "name": "West Georgia Street",
      "location": [-123.120712, 49.282695],
      "distance": 12.34
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `coordinate` | `[lon, lat]` - Point to search from |
| `number` | (optional) Number of nearest points to return, default 1 |

---

### 2. Route

Get driving directions between two or more points.

**Request:**
```bash
curl -X POST http://localhost:8080/route \
  -H "Content-Type: application/json" \
  -d '{
    "coordinates": [
      [-123.1207, 49.2827],
      [-122.8490, 49.1913]
    ],
    "steps": true,
    "geometries": "geojson"
  }'
```

**Response:**
```json
{
  "routes": [
    {
      "distance": 32109,
      "duration": 2134,
      "geometry": { "type": "LineString", "coordinates": [...] },
      "legs": [
        {
          "distance": 32109,
          "duration": 2134,
          "summary": "Trans-Canada Highway",
          "steps": [
            {
              "distance": 245,
              "duration": 32,
              "name": "West Georgia Street",
              "maneuver": {
                "type": "depart",
                "modifier": "right",
                "location": [-123.1207, 49.2827]
              }
            }
          ]
        }
      ]
    }
  ],
  "waypoints": [
    { "name": "West Georgia Street", "location": [-123.1207, 49.2827] },
    { "name": "King George Boulevard", "location": [-122.8490, 49.1913] }
  ]
}
```

| Field | Description |
|-------|-------------|
| `coordinates` | Array of `[lon, lat]` points (minimum 2) |
| `steps` | (optional) Include turn-by-turn instructions |
| `geometries` | (optional) `"polyline"`, `"polyline6"`, or `"geojson"` |
| `overview` | (optional) `"full"`, `"simplified"`, or `"false"` |

**Output units:** `distance` in meters, `duration` in seconds.

---

### 3. Matrix

Get distance and duration matrix between all coordinate pairs. Useful for logistics, delivery routing, or finding the closest location from multiple options.

**Request:**
```bash
curl -X POST http://localhost:8080/matrix \
  -H "Content-Type: application/json" \
  -d '{
    "coordinates": [
      [-123.1207, 49.2827],
      [-123.1162, 49.2463],
      [-122.8490, 49.1913],
      [-122.9820, 49.2488]
    ]
  }'
```

**Response:**
```json
{
  "distance_matrix": [
    [0, 4521, 32109, 12045],
    [4893, 0, 28765, 9823],
    [31876, 28432, 0, 19654],
    [12301, 9567, 19234, 0]
  ],
  "duration_matrix": [
    [0, 542, 2134, 987],
    [561, 0, 1987, 812],
    [2098, 1876, 0, 1432],
    [1012, 834, 1398, 0]
  ]
}
```

| Field | Description |
|-------|-------------|
| `coordinates` | Array of `[lon, lat]` points |

**Output:** NxN matrices where `matrix[i][j]` = value from point `i` to point `j`.
- `distance_matrix` in meters
- `duration_matrix` in seconds

---

### 4. Trip

Solve the Traveling Salesman Problem - find the optimal order to visit all points.

**Request:**
```bash
curl -X POST http://localhost:8080/trip \
  -H "Content-Type: application/json" \
  -d '{
    "coordinates": [
      [-123.1207, 49.2827],
      [-123.1162, 49.2463],
      [-122.8490, 49.1913],
      [-122.9820, 49.2488]
    ],
    "roundtrip": true,
    "geometries": "geojson"
  }'
```

**Response:**
```json
{
  "trips": [
    {
      "distance": 65432,
      "duration": 4521,
      "geometry": { "type": "LineString", "coordinates": [...] }
    }
  ],
  "waypoints": [
    { "name": "West Georgia Street", "location": [-123.1207, 49.2827], "waypoint_index": 0 },
    { "name": "4th Avenue", "location": [-123.1162, 49.2463], "waypoint_index": 1 },
    { "name": "Metrotown", "location": [-122.9820, 49.2488], "waypoint_index": 2 },
    { "name": "King George Boulevard", "location": [-122.8490, 49.1913], "waypoint_index": 3 }
  ]
}
```

| Field | Description |
|-------|-------------|
| `coordinates` | Array of `[lon, lat]` points to visit |
| `roundtrip` | (optional) Return to starting point, default `true` |
| `geometries` | (optional) `"polyline"`, `"polyline6"`, or `"geojson"` |

**Key output:** `waypoint_index` shows the optimal visit order.

---

### 5. Match

Snap a GPS trace to the road network (map matching). Useful for cleaning up noisy GPS data.

**Request:**
```bash
curl -X POST http://localhost:8080/match \
  -H "Content-Type: application/json" \
  -d '{
    "coordinates": [
      [-123.1207, 49.2827],
      [-123.1200, 49.2830],
      [-123.1195, 49.2835],
      [-123.1188, 49.2840]
    ],
    "radiuses": [10, 10, 10, 10],
    "geometries": "geojson"
  }'
```

**Response:**
```json
{
  "matchings": [
    {
      "distance": 156.7,
      "duration": 23.4,
      "confidence": 0.95,
      "geometry": { "type": "LineString", "coordinates": [...] }
    }
  ],
  "tracepoints": [
    { "name": "West Georgia Street", "location": [-123.120698, 49.282701], "matchings_index": 0, "waypoint_index": 0 },
    { "name": "West Georgia Street", "location": [-123.120012, 49.283002], "matchings_index": 0, "waypoint_index": 1 },
    { "name": "West Georgia Street", "location": [-123.119503, 49.283498], "matchings_index": 0, "waypoint_index": 2 },
    { "name": "West Georgia Street", "location": [-123.118799, 49.284001], "matchings_index": 0, "waypoint_index": 3 }
  ]
}
```

| Field | Description |
|-------|-------------|
| `coordinates` | Array of `[lon, lat]` GPS points |
| `timestamps` | (optional) Unix timestamps for each point |
| `radiuses` | (optional) GPS accuracy in meters for each point |
| `geometries` | (optional) `"polyline"`, `"polyline6"`, or `"geojson"` |

**Key output:** `confidence` (0-1) indicates how well the trace matched the road network.

---

### 6. Health

Simple health check endpoint.

**Request:**
```bash
curl http://localhost:8080/health
```

**Response:**
```json
{
  "status": "healthy"
}
```

---

## Data Setup

OSRM requires preprocessed map data. To set up data for a region:

### 1. Download OpenStreetMap data

```bash
# Example: British Columbia
wget https://download.geofabrik.de/north-america/canada/british-columbia-latest.osm.pbf
```

### 2. Preprocess with OSRM

```bash
# Extract
docker run -v $(pwd):/data osrm/osrm-backend osrm-extract -p /opt/car.lua /data/british-columbia-latest.osm.pbf

# Partition
docker run -v $(pwd):/data osrm/osrm-backend osrm-partition /data/british-columbia-latest.osrm

# Customize
docker run -v $(pwd):/data osrm/osrm-backend osrm-customize /data/british-columbia-latest.osrm
```

This creates ~30 `.osrm*` files in your data directory.

### 3. Update configuration

Update the OSRM filename in:
- `start.sh` (line 4)
- `k8s/deployment.yaml` (line 31)

---

## Deployment Options

### Option 1: Single Docker Container

```bash
docker build -t geospatial:latest .
docker run -d -p 8080:8080 -v /path/to/data:/data geospatial:latest
```

### Option 2: Kubernetes (Minikube)

See [README-K8S.md](README-K8S.md) for full Kubernetes deployment instructions.

```bash
# Quick start
./setup-k8s.ps1  # Windows
./setup-k8s.sh   # Mac/Linux
```

---

## Python Client Example

```python
import requests

API_URL = "http://localhost:8080"

# Get distance matrix
response = requests.post(f"{API_URL}/matrix", json={
    "coordinates": [
        [-123.1207, 49.2827],  # Vancouver
        [-123.1162, 49.2463],  # Kitsilano
        [-122.8490, 49.1913],  # Surrey
    ]
})
data = response.json()
print("Distance matrix (km):")
for row in data["distance_matrix"]:
    print([round(d/1000, 2) for d in row])

# Get optimal route order
response = requests.post(f"{API_URL}/trip", json={
    "coordinates": [
        [-123.1207, 49.2827],
        [-123.1162, 49.2463],
        [-122.8490, 49.1913],
        [-122.9820, 49.2488]
    ]
})
data = response.json()
print("\nOptimal visit order:")
for wp in sorted(data["waypoints"], key=lambda x: x["waypoint_index"]):
    print(f"  {wp['waypoint_index']}: {wp['name']}")
```

---

## Why Use This?

| Feature | Google Maps API | This Project |
|---------|-----------------|--------------|
| Cost | $5-10 per 1000 requests | Free |
| Privacy | Data sent to Google | Runs locally |
| Rate limits | Yes | No |
| Offline | No | Yes |
| Customizable | No | Yes |

**Best for:** Local development, testing, batch processing, privacy-sensitive applications, offline use.

---

## License

MIT
