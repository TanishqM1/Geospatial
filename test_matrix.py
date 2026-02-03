import requests
import pandas as pd


# === Locations with readable names ===
locations = {
    "Vancouver": [-123.1207, 49.2827],
    "Kitsilano": [-123.1162, 49.2463],
    "Surrey": [-122.8490, 49.1913],
    "Burnaby": [-122.9820, 49.2488],
}

coords = list(locations.values())
names = list(locations.keys())

url = "http://localhost:8080/matrix"
payload = {"coordinates": coords}

print("📤 Sending request to Flask API...")
response = requests.post(url, json=payload)
print(f"📥 Status Code: {response.status_code}\n")

if response.ok:
    data = response.json()
    dist = data.get("distance_matrix", [])
    dur = data.get("duration_matrix", [])

    df_dist = pd.DataFrame(dist, columns=names, index=names)
    df_dur = pd.DataFrame(dur, columns=names, index=names)

    print("🚗 Distance Matrix (km):\n")
    print(df_dist / 1000, "\n")

    print("⏱️ Duration Matrix (min):\n")
    print(df_dur / 60, "\n")

else:
    print("❌ Error:", response.text)
