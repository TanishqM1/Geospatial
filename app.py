from flask import Flask, request, jsonify
import requests
import os

app = Flask(__name__)

# Read OSRM URL from environment (default to localhost for backward compatibility)
OSRM_BASE_URL = os.getenv("OSRM_URL", "http://localhost:5000")

@app.route("/matrix", methods=["POST"])
def matrix():
    data = request.get_json()
    coords = data.get("coordinates", [])
    if not coords:
        return jsonify({"error": "no coordinates"}), 400

    coord_str = ";".join([f"{c[0]},{c[1]}" for c in coords])
    url = f"{OSRM_BASE_URL}/table/v1/driving/{coord_str}?annotations=distance,duration"
    r = requests.get(url)
    osrm_data = r.json()

    # Extract matrices
    distance_matrix = osrm_data.get("distances", [])
    duration_matrix = osrm_data.get("durations", [])

    # Return a clean response
    print("🛰️ OSRM raw response:", osrm_data)
    return jsonify({
        "distance_matrix": distance_matrix,
        "duration_matrix": duration_matrix
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
