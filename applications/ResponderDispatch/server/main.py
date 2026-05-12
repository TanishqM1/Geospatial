from typing import Optional, List, Dict, Any
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import httpx
import os

app = FastAPI(title="Nearest Responder Sidecar")
app.mount("/static", StaticFiles(directory="./static"), name="static")

GEOSPATIAL_URL = os.getenv("GEOSPATIAL_URL", "http://127.0.0.1:8080").rstrip("/")

# Mocked "current live GPS" responders
# Distributed across southern BC: Lower Mainland (R1-R3), Kelowna (R4), Interior (R5)
DEFAULT_RESPONDERS = [
    {"id": "R1", "name": "Unit Alpha", "coordinate": [-123.1, 49.26]},       # Vancouver
    {"id": "R2", "name": "Unit Bravo", "coordinate": [-122.8, 49.1]},        # Surrey
    {"id": "R3", "name": "Unit Charlie", "coordinate": [-122.3, 49.0]},      # Abbotsford
    {"id": "R4", "name": "Unit Delta", "coordinate": [-119.6, 49.7]},       # Kelowna
    {"id": "R5", "name": "Unit Echo", "coordinate": [-119.0, 49.85]},       # Interior (towards Alberta)
]

DEFAULT_EVENT = {
    "name": "Incident: Traffic Collision",
    "coordinate": [-122.7600, 49.1300],
}


class DispatchRequest(BaseModel):
    responders: Optional[List[Dict[str, Any]]] = None
    event: Optional[Dict[str, Any]] = None
    metric: Optional[str] = "duration"  # duration or distance


@app.get("/", response_class=HTMLResponse)
async def index():
    try:
        with open("./static/index.html", "r", encoding="utf-8") as f:
            return HTMLResponse(f.read())
    except Exception:
        return HTMLResponse("<h1>Nearest Responder</h1><p>Open /static/index.html</p>")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/defaults")
async def defaults():
    return {
        "responders": DEFAULT_RESPONDERS,
        "event": DEFAULT_EVENT,
    }


async def snap_to_road(client: httpx.AsyncClient, coord: List[float]) -> List[float]:
    """Snap [lon, lat] to the nearest drivable edge via Geospatial /nearest."""
    resp = await client.post(
        f"{GEOSPATIAL_URL}/nearest",
        json={"coordinate": coord, "number": 1},
        timeout=20.0,
    )
    resp.raise_for_status()
    body = resp.json()
    loc = body.get("location")
    if isinstance(loc, list) and len(loc) == 2:
        return [float(loc[0]), float(loc[1])]
    wps = body.get("waypoints") or []
    if wps and isinstance(wps[0].get("location"), list) and len(wps[0]["location"]) == 2:
        loc2 = wps[0]["location"]
        return [float(loc2[0]), float(loc2[1])]
    raise RuntimeError("nearest returned no location")


async def route_to_event(client: httpx.AsyncClient, from_coord: List[float], event_coord: List[float]):
    resp = await client.post(
        f"{GEOSPATIAL_URL}/route",
        json={
            "coordinates": [from_coord, event_coord],
            "geometries": "geojson",
            "steps": False,
            "overview": "full",
        },
        timeout=25.0,
    )
    if resp.status_code >= 400:
        try:
            detail = resp.json().get("error", resp.text)
        except Exception:
            detail = resp.text or resp.reason_phrase
        raise RuntimeError(str(detail))
    return resp.json()


@app.post("/dispatch/nearest")
async def dispatch_nearest(req: DispatchRequest):
    responders = req.responders if req.responders else DEFAULT_RESPONDERS
    event = req.event if req.event else DEFAULT_EVENT

    if not responders:
        raise HTTPException(status_code=400, detail="No responders provided")
    if not event or "coordinate" not in event:
        raise HTTPException(status_code=400, detail="No valid event coordinate provided")

    ranked = []
    async with httpx.AsyncClient() as client:
        try:
            event_coord = await snap_to_road(client, event["coordinate"])
        except Exception as e:
            raise HTTPException(
                status_code=502,
                detail=f"Could not snap incident to road network (is Geospatial running at {GEOSPATIAL_URL}?): {e}",
            )

        for responder in responders:
            if "coordinate" not in responder:
                continue
            responder_coord_raw = responder["coordinate"]
            try:
                responder_coord = await snap_to_road(client, responder_coord_raw)
                route_json = await route_to_event(client, responder_coord, event_coord)
                duration = float(route_json.get("duration") or 0.0)
                distance = float(route_json.get("distance") or 0.0)
                ranked.append(
                    {
                        "id": responder.get("id"),
                        "name": responder.get("name", "Unknown Unit"),
                        "from": responder_coord_raw,
                        "from_snapped": responder_coord,
                        "to": event["coordinate"],
                        "to_snapped": event_coord,
                        "duration": duration,
                        "distance": distance,
                        "route": route_json,
                    }
                )
            except Exception as e:
                ranked.append(
                    {
                        "id": responder.get("id"),
                        "name": responder.get("name", "Unknown Unit"),
                        "from": responder.get("coordinate"),
                        "to": event_coord,
                        "error": str(e),
                    }
                )

    viable = [r for r in ranked if "error" not in r]
    if not viable:
        errors = [f"{r.get('id')}: {r.get('error')}" for r in ranked if r.get("error")]
        msg = "No valid routes computed from backend."
        if errors:
            msg += " " + "; ".join(errors[:5])
        raise HTTPException(status_code=502, detail=msg)

    key_metric = "duration" if req.metric == "duration" else "distance"
    viable.sort(key=lambda x: x.get(key_metric, 10**18))

    winner = viable[0]

    return JSONResponse(
        {
            "event": event,
            "metric": key_metric,
            "steps": [
                "Snapped incident and responder GPS to the road network (/nearest)",
                "Requested driving routes to the snapped incident (/route)",
                f"Compared responders by {key_metric}",
                f"Selected nearest responder: {winner['name']} ({winner['id']})",
            ],
            "ranked": viable,
            "winner": winner,
            "all_attempts": ranked,
        }
    )
