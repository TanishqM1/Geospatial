from flask import Flask, request, jsonify
import requests
import os

app = Flask(__name__)

OSRM_BASE_URL = os.getenv("OSRM_URL", "http://localhost:5000")


# ------------------------------------------------------------------------------
# Health Check
# ------------------------------------------------------------------------------
@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint for Kubernetes probes."""
    return jsonify({"status": "healthy"})


# ------------------------------------------------------------------------------
# Nearest - Find nearest road to a coordinate
# ------------------------------------------------------------------------------
@app.route("/nearest", methods=["POST"])
def nearest():
    """
    Find the nearest road/point to a coordinate.

    Input:
        {
            "coordinate": [-123.1207, 49.2827],
            "number": 1  // optional, default 1
        }

    Output:
        {
            "waypoints": [
                {
                    "name": "West Georgia Street",
                    "location": [-123.120712, 49.282695],
                    "distance": 12.34
                }
            ]
        }
    """
    data = request.get_json()
    coord = data.get("coordinate")
    if not coord or len(coord) != 2:
        return jsonify({"error": "coordinate required as [lon, lat]"}), 400

    number = data.get("number", 1)
    url = f"{OSRM_BASE_URL}/nearest/v1/driving/{coord[0]},{coord[1]}?number={number}"

    r = requests.get(url)
    osrm_data = r.json()

    if osrm_data.get("code") != "Ok":
        return jsonify({"error": osrm_data.get("message", "OSRM error")}), 400

    waypoints = []
    for wp in osrm_data.get("waypoints", []):
        waypoints.append({
            "name": wp.get("name", ""),
            "location": wp.get("location"),
            "distance": wp.get("distance")
        })

    return jsonify({"waypoints": waypoints})


# ------------------------------------------------------------------------------
# Route - Get turn-by-turn directions between points
# ------------------------------------------------------------------------------
@app.route("/route", methods=["POST"])
def route():
    """
    Get driving directions between two or more points.

    Input:
        {
            "coordinates": [
                [-123.1207, 49.2827],
                [-122.8490, 49.1913]
            ],
            "steps": true,           // optional, include turn-by-turn steps
            "geometries": "geojson", // optional: "polyline", "polyline6", "geojson"
            "overview": "full"       // optional: "full", "simplified", "false"
        }

    Output:
        {
            "routes": [...],
            "waypoints": [...]
        }
    """
    data = request.get_json()
    coords = data.get("coordinates", [])
    if len(coords) < 2:
        return jsonify({"error": "at least 2 coordinates required"}), 400

    coord_str = ";".join([f"{c[0]},{c[1]}" for c in coords])

    # Build query params
    params = []
    if data.get("steps", False):
        params.append("steps=true")
    if data.get("geometries"):
        params.append(f"geometries={data['geometries']}")
    if data.get("overview"):
        params.append(f"overview={data['overview']}")

    query = "&".join(params) if params else ""
    url = f"{OSRM_BASE_URL}/route/v1/driving/{coord_str}"
    if query:
        url += f"?{query}"

    r = requests.get(url)
    osrm_data = r.json()

    if osrm_data.get("code") != "Ok":
        return jsonify({"error": osrm_data.get("message", "OSRM error")}), 400

    # Extract route info
    routes = []
    for route in osrm_data.get("routes", []):
        route_info = {
            "distance": route.get("distance"),  # meters
            "duration": route.get("duration"),  # seconds
            "geometry": route.get("geometry"),
        }
        if "legs" in route:
            route_info["legs"] = []
            for leg in route["legs"]:
                leg_info = {
                    "distance": leg.get("distance"),
                    "duration": leg.get("duration"),
                    "summary": leg.get("summary", "")
                }
                if "steps" in leg:
                    leg_info["steps"] = []
                    for step in leg["steps"]:
                        leg_info["steps"].append({
                            "distance": step.get("distance"),
                            "duration": step.get("duration"),
                            "name": step.get("name", ""),
                            "maneuver": step.get("maneuver", {})
                        })
                route_info["legs"].append(leg_info)
        routes.append(route_info)

    waypoints = []
    for wp in osrm_data.get("waypoints", []):
        waypoints.append({
            "name": wp.get("name", ""),
            "location": wp.get("location")
        })

    return jsonify({
        "routes": routes,
        "waypoints": waypoints
    })


# ------------------------------------------------------------------------------
# Matrix (Table) - Distance/duration matrix between all coordinate pairs
# ------------------------------------------------------------------------------
@app.route("/matrix", methods=["POST"])
def matrix():
    """
    Get distance and duration matrix between all coordinate pairs.

    Input:
        {
            "coordinates": [
                [-123.1207, 49.2827],
                [-123.1162, 49.2463],
                [-122.8490, 49.1913]
            ]
        }

    Output:
        {
            "distance_matrix": [[0, 4521, 32109], ...],  // meters
            "duration_matrix": [[0, 542, 2134], ...]     // seconds
        }
    """
    data = request.get_json()
    coords = data.get("coordinates", [])
    if not coords:
        return jsonify({"error": "coordinates required"}), 400

    coord_str = ";".join([f"{c[0]},{c[1]}" for c in coords])
    url = f"{OSRM_BASE_URL}/table/v1/driving/{coord_str}?annotations=distance,duration"

    r = requests.get(url)
    osrm_data = r.json()

    if osrm_data.get("code") != "Ok":
        return jsonify({"error": osrm_data.get("message", "OSRM error")}), 400

    return jsonify({
        "distance_matrix": osrm_data.get("distances", []),
        "duration_matrix": osrm_data.get("durations", [])
    })


# ------------------------------------------------------------------------------
# Trip - Solve traveling salesman problem (optimal route visiting all points)
# ------------------------------------------------------------------------------
@app.route("/trip", methods=["POST"])
def trip():
    """
    Solve the Traveling Salesman Problem - find optimal order to visit all points.

    Input:
        {
            "coordinates": [
                [-123.1207, 49.2827],
                [-123.1162, 49.2463],
                [-122.8490, 49.1913],
                [-122.9820, 49.2488]
            ],
            "roundtrip": true,       // optional, return to start (default true)
            "geometries": "geojson"  // optional: "polyline", "polyline6", "geojson"
        }

    Output:
        {
            "trips": [...],
            "waypoints": [...]  // includes waypoint_index for optimal order
        }
    """
    data = request.get_json()
    coords = data.get("coordinates", [])
    if len(coords) < 2:
        return jsonify({"error": "at least 2 coordinates required"}), 400

    coord_str = ";".join([f"{c[0]},{c[1]}" for c in coords])

    # Build query params
    params = []
    if "roundtrip" in data:
        params.append(f"roundtrip={'true' if data['roundtrip'] else 'false'}")
    if data.get("geometries"):
        params.append(f"geometries={data['geometries']}")

    query = "&".join(params) if params else ""
    url = f"{OSRM_BASE_URL}/trip/v1/driving/{coord_str}"
    if query:
        url += f"?{query}"

    r = requests.get(url)
    osrm_data = r.json()

    if osrm_data.get("code") != "Ok":
        return jsonify({"error": osrm_data.get("message", "OSRM error")}), 400

    # Extract trip info
    trips = []
    for trip in osrm_data.get("trips", []):
        trips.append({
            "distance": trip.get("distance"),  # meters
            "duration": trip.get("duration"),  # seconds
            "geometry": trip.get("geometry")
        })

    waypoints = []
    for wp in osrm_data.get("waypoints", []):
        waypoints.append({
            "name": wp.get("name", ""),
            "location": wp.get("location"),
            "waypoint_index": wp.get("waypoint_index"),  # optimal visit order
            "trips_index": wp.get("trips_index")
        })

    return jsonify({
        "trips": trips,
        "waypoints": waypoints
    })


# ------------------------------------------------------------------------------
# Match - Snap GPS trace to roads (map matching)
# ------------------------------------------------------------------------------
@app.route("/match", methods=["POST"])
def match():
    """
    Snap a GPS trace to the road network (map matching).

    Input:
        {
            "coordinates": [
                [-123.1207, 49.2827],
                [-123.1200, 49.2830],
                [-123.1195, 49.2835]
            ],
            "timestamps": [1609459200, 1609459210, 1609459220],  // optional, unix timestamps
            "radiuses": [10, 10, 10],  // optional, GPS accuracy in meters
            "geometries": "geojson"    // optional: "polyline", "polyline6", "geojson"
        }

    Output:
        {
            "matchings": [...],
            "tracepoints": [...]
        }
    """
    data = request.get_json()
    coords = data.get("coordinates", [])
    if len(coords) < 2:
        return jsonify({"error": "at least 2 coordinates required"}), 400

    coord_str = ";".join([f"{c[0]},{c[1]}" for c in coords])

    # Build query params
    params = []
    if data.get("timestamps"):
        params.append(f"timestamps={';'.join(map(str, data['timestamps']))}")
    if data.get("radiuses"):
        params.append(f"radiuses={';'.join(map(str, data['radiuses']))}")
    if data.get("geometries"):
        params.append(f"geometries={data['geometries']}")

    query = "&".join(params) if params else ""
    url = f"{OSRM_BASE_URL}/match/v1/driving/{coord_str}"
    if query:
        url += f"?{query}"

    r = requests.get(url)
    osrm_data = r.json()

    if osrm_data.get("code") != "Ok":
        return jsonify({"error": osrm_data.get("message", "OSRM error")}), 400

    # Extract matching info
    matchings = []
    for matching in osrm_data.get("matchings", []):
        matchings.append({
            "distance": matching.get("distance"),
            "duration": matching.get("duration"),
            "confidence": matching.get("confidence"),
            "geometry": matching.get("geometry")
        })

    tracepoints = []
    for tp in osrm_data.get("tracepoints", []):
        if tp is None:
            tracepoints.append(None)
        else:
            tracepoints.append({
                "name": tp.get("name", ""),
                "location": tp.get("location"),
                "matchings_index": tp.get("matchings_index"),
                "waypoint_index": tp.get("waypoint_index")
            })

    return jsonify({
        "matchings": matchings,
        "tracepoints": tracepoints
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
