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
- OSRM data files in `./data/` folder (see [Data Setup](#data-setup))

### Start the Service

**Mac/Linux:**
```bash
./start-osrm.sh
```

**Windows (PowerShell):**
```powershell
.\start-osrm.ps1
```

The script will:
1. Build the Docker image
2. Start the container
3. Wait for the service to be ready
4. Print the API URL and test commands

### Stop the Service

```bash
docker stop geospatial
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

### 4. Match (Map Matching)

Snap a GPS trace to the road network. This is useful when you have raw GPS data that's slightly inaccurate and you want to:

1. **Clean up noisy GPS data** - GPS is typically accurate to 5-15 meters, which can place points off the actual road
2. **Determine which roads were traveled** - Get street names and actual route taken
3. **Calculate true distance traveled** - Road distance, not straight-line distance between GPS points
4. **Reconstruct a route from sparse GPS points** - Fill in the gaps between logged positions

#### When to use `/match`

| Scenario | Example |
|----------|---------|
| Fleet tracking | A delivery truck logs GPS every 30 seconds. You want to know exactly which streets it drove on. |
| Fitness apps | A runner's GPS watch recorded a route. You want to snap it to actual trails/roads for accurate distance. |
| Data cleaning | You have historical GPS logs with some points in buildings or lakes due to GPS drift. |
| Route reconstruction | A vehicle logged sparse GPS points. You want the complete route with all turns. |

#### How it works

```
Raw GPS points (noisy):          Matched result (on road):

    •
      •   •                           ═══════•═══════
  •     •                                    │
    •                                        •
      •                                      │
                                       ══════•══════
```

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
| `coordinates` | Array of `[lon, lat]` GPS points (in order they were recorded) |
| `timestamps` | (optional) Unix timestamps for each point - helps with accuracy |
| `radiuses` | (optional) GPS accuracy in meters for each point (default: 5m). Use higher values for less accurate GPS. |
| `geometries` | (optional) `"polyline"`, `"polyline6"`, or `"geojson"` |

**Output explained:**
- `confidence` (0-1): How well the GPS trace matched roads. Below 0.5 suggests the trace may not be on roads.
- `distance`: Actual road distance traveled (meters)
- `duration`: Estimated travel time (seconds)
- `geometry`: The snapped route as a line on actual roads
- `tracepoints`: Each input point snapped to its nearest road location, with street name

#### Python example

```python
import requests

# Raw GPS trace from a vehicle
gps_trace = [
    [-123.1207, 49.2827],  # Slightly off road
    [-123.1200, 49.2830],  # Slightly off road
    [-123.1195, 49.2835],  # Slightly off road
    [-123.1188, 49.2840],  # Slightly off road
]

response = requests.post("http://localhost:8080/match", json={
    "coordinates": gps_trace,
    "radiuses": [15] * len(gps_trace),  # GPS accurate to ~15 meters
    "geometries": "geojson"
})

data = response.json()

# Check match quality
confidence = data["matchings"][0]["confidence"]
print(f"Match confidence: {confidence:.0%}")

# Get actual distance traveled
distance_km = data["matchings"][0]["distance"] / 1000
print(f"Distance traveled: {distance_km:.2f} km")

# Get street names
streets = set(tp["name"] for tp in data["tracepoints"] if tp)
print(f"Streets traveled: {', '.join(streets)}")

# Get corrected coordinates
corrected = [tp["location"] for tp in data["tracepoints"] if tp]
print(f"Corrected coordinates: {corrected}")
```

---

### 5. Health

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
mkdir -p data
cd data

# Extract
docker run -v $(pwd):/data osrm/osrm-backend osrm-extract -p /opt/car.lua /data/british-columbia-latest.osm.pbf

# Partition
docker run -v $(pwd):/data osrm/osrm-backend osrm-partition /data/british-columbia-latest.osrm

# Customize
docker run -v $(pwd):/data osrm/osrm-backend osrm-customize /data/british-columbia-latest.osrm
```

This creates ~30 `.osrm*` files in your data directory.

### 3. Update configuration

Update the OSRM filename in `start.sh` (line 4) to match your data file.

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

# Get driving directions
response = requests.post(f"{API_URL}/route", json={
    "coordinates": [
        [-123.1207, 49.2827],
        [-122.8490, 49.1913]
    ],
    "steps": True
})
data = response.json()
route = data["routes"][0]
print(f"\nRoute: {route['distance']/1000:.1f} km, {route['duration']/60:.0f} min")
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

## Advanced: Kubernetes Deployment

For production-like deployment with Kubernetes, see [README-K8S.md](README-K8S.md).

---

## License

MIT
