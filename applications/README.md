# Applications

Bundled demos that call the Geospatial API (default `http://127.0.0.1:8080`).

| Directory | Port | Description |
|-----------|------|-------------|
| [VRP](VRP/) | 8000 | OR-Tools TSP through BC points |
| [ResponderDispatch](ResponderDispatch/) | 8100 | Nearest responder to an incident |

From the Geospatial repo root, `./scripts/local/start-all.sh` starts the API in Docker and, unless `START_DEMOS=0`, launches both apps in the background. `./scripts/local/stop-all.sh` tears them down.
