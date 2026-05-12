from typing import List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import httpx
from ortools.constraint_solver import pywrapcp, routing_enums_pb2
import math
import os

app = FastAPI(title="VRP Sidecar - OR-Tools Demo")

# Serve static frontend from ./static
app.mount("/static", StaticFiles(directory="./static"), name="static")

DEFAULT_POINTS = [
    {
        "name": "Vancouver",
        "landmark": "Stanley Park",
        "coordinate": [-123.1207, 49.2827],
    },
    {
        "name": "Abbotsford",
        "landmark": "Mill Lake Park",
        "coordinate": [-122.3026, 49.0504],
    },
    {
        "name": "Surrey",
        "landmark": "Holland Park / Central City",
        "coordinate": [-122.8275, 49.1117],
    },
    {
        "name": "Burnaby",
        "landmark": "Metrotown",
        "coordinate": [-122.9805, 49.2488],
    },
    {
        "name": "Kelowna",
        "landmark": "Okanagan Lake",
        "coordinate": [-119.4960, 49.8880],
    },
]

_GEOSPATIAL = os.getenv("GEOSPATIAL_URL", "http://127.0.0.1:8080").rstrip("/")
BACKEND_MATRIX_URL = f"{_GEOSPATIAL}/matrix"
BACKEND_ROUTE_URL = f"{_GEOSPATIAL}/route"

class SolveRequest(BaseModel):
    coordinates: Optional[List[List[float]]] = None
    names: Optional[List[str]] = None
    metric: Optional[str] = "duration"  # 'duration' or 'distance'


def get_coords_and_names(req: SolveRequest):
    if req.coordinates:
        coords = req.coordinates
        if req.names and len(req.names) == len(coords):
            names = req.names
        else:
            names = [f"Stop {i}" for i in range(len(coords))]
    else:
        coords = [p["coordinate"] for p in DEFAULT_POINTS]
        names = [f"{p['name']} ({p['landmark']})" for p in DEFAULT_POINTS]
    return coords, names


def build_traversal(order, coords, names):
    traversal = []
    for seq, idx in enumerate(order):
        is_start = seq == 0
        is_end = seq == len(order) - 1
        traversal.append(
            {
                "sequence": seq,
                "index": idx,
                "name": names[idx],
                "coordinate": coords[idx],
                "is_start": is_start,
                "is_return_to_start": is_end,
            }
        )
    return traversal


@app.get("/defaults")
async def defaults():
    points = []
    for idx, point in enumerate(DEFAULT_POINTS):
        points.append(
            {
                "index": idx,
                "name": point["name"],
                "landmark": point["landmark"],
                "coordinate": point["coordinate"],
                "is_start": idx == 0,
            }
        )

    return {
        "start_index": 0,
        "points": points,
    }

@app.get("/", response_class=HTMLResponse)
async def index():
    try:
        with open("./static/index.html", "r", encoding="utf-8") as f:
            return HTMLResponse(f.read())
    except Exception:
        return HTMLResponse("<h1>VRP Sidecar</h1><p>Open /static/index.html</p>")

@app.post("/solve/tsp")
async def solve_tsp(req: SolveRequest):
    coords, names = get_coords_and_names(req)
    if len(coords) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 coordinates")

    # Request matrix from main backend
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(BACKEND_MATRIX_URL, json={"coordinates": coords})
            resp.raise_for_status()
            matrix_json = resp.json()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to fetch matrix from backend: {e}")

    dur = matrix_json.get("durations") or matrix_json.get("duration_matrix")
    dist = matrix_json.get("distances") or matrix_json.get("distance_matrix")
    if req.metric == "duration":
        matrix = dur or dist
    else:
        matrix = dist or dur

    if not matrix:
        raise HTTPException(status_code=500, detail="No matrix data returned from backend")

    # Convert matrix to integer costs (OR-Tools requires integers)
    n = len(matrix)
    int_matrix = []
    for i in range(n):
        row = []
        for j in range(n):
            val = matrix[i][j]
            if val is None:
                val = 1
            # scale to integer (seconds or meters) and clamp
            try:
                iv = int(math.ceil(float(val)))
            except Exception:
                iv = 1
            row.append(max(0, iv))
        int_matrix.append(row)

    # Setup OR-Tools TSP (single vehicle, return to depot)
    manager = pywrapcp.RoutingIndexManager(n, 1, 0)
    routing = pywrapcp.RoutingModel(manager)

    def distance_callback(from_index, to_index):
        from_node = manager.IndexToNode(from_index)
        to_node = manager.IndexToNode(to_index)
        return int_matrix[from_node][to_node]

    transit_callback_index = routing.RegisterTransitCallback(distance_callback)
    routing.SetArcCostEvaluatorOfAllVehicles(transit_callback_index)

    search_parameters = pywrapcp.DefaultRoutingSearchParameters()
    search_parameters.first_solution_strategy = (
        routing_enums_pb2.FirstSolutionStrategy.PATH_CHEAPEST_ARC
    )
    search_parameters.local_search_metaheuristic = (
        routing_enums_pb2.LocalSearchMetaheuristic.GUIDED_LOCAL_SEARCH
    )
    search_parameters.time_limit.seconds = 3

    solution = routing.SolveWithParameters(search_parameters)
    if solution is None:
        raise HTTPException(status_code=500, detail="No solution found by OR-Tools")

    # Extract route
    index = routing.Start(0)
    route = []
    total_cost = 0
    while not routing.IsEnd(index):
        node = manager.IndexToNode(index)
        route.append(node)
        previous_index = index
        index = solution.Value(routing.NextVar(index))
        total_cost += routing.GetArcCostForVehicle(previous_index, index, 0)
    # add final depot (should be 0)
    route.append(manager.IndexToNode(index))

    # Compute total distance/duration from original matrix (not integer scaled)
    total_metric = 0.0
    for i in range(len(route) - 1):
        a = route[i]
        b = route[i + 1]
        total_metric += float(matrix[a][b] or 0)

    traversal = build_traversal(route, coords, names)

    return JSONResponse(
        {
            "order": route,
            "traversal": traversal,
            "total_cost_int": int(total_cost),
            "total_metric": total_metric,
            "coordinates": coords,
            "names": names,
            "start_index": 0,
            "metric": req.metric,
        }
    )


@app.post("/solve/tsp_with_routes")
async def solve_tsp_with_routes(req: SolveRequest):
    # Reuse the same TSP logic to get an order
    solve_resp = await solve_tsp(req)
    # solve_tsp returns a JSONResponse; extract its content
    if isinstance(solve_resp, JSONResponse):
        body = solve_resp.body
        # JSONResponse.body is bytes
        import json as _json
        parsed = _json.loads(body)
    else:
        # Fallback: assume dict
        parsed = solve_resp

    order = parsed.get("order")
    coords = parsed.get("coordinates")
    names = parsed.get("names")
    traversal = parsed.get("traversal")
    metric = parsed.get("metric")

    if not order or not coords:
        raise HTTPException(status_code=500, detail="Solver did not return route/order")

    legs = []
    async with httpx.AsyncClient() as client:
        for i in range(len(order) - 1):
            a = order[i]
            b = order[i + 1]
            pt_a = coords[a]
            pt_b = coords[b]
            try:
                resp = await client.post(
                    BACKEND_ROUTE_URL,
                    json={
                        "coordinates": [pt_a, pt_b],
                        "geometries": "geojson",
                        "steps": False,
                        "overview": "full",
                    },
                    timeout=20.0,
                )
                resp.raise_for_status()
                route_json = resp.json()
            except Exception as e:
                route_json = {"error": str(e)}

            legs.append({
                "from_index": a,
                "to_index": b,
                "from": pt_a,
                "to": pt_b,
                "route": route_json,
            })

    return JSONResponse({
        "order": order,
        "traversal": traversal,
        "coordinates": coords,
        "names": names,
        "start_index": 0,
        "metric": metric,
        "legs": legs,
        "total_metric": parsed.get("total_metric"),
        "total_cost_int": parsed.get("total_cost_int"),
    })

@app.get("/health")
async def health():
    return {"status": "ok"}
