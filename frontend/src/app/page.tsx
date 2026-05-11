"use client";

import { useState, useEffect } from "react";
import { ApiMode } from "@/types/api";
import { modeInfo } from "@/config/modeInfo";
import { HealthIndicator } from "@/components/HealthIndicator";
import { ResultsDisplay } from "@/components/ResultsDisplay";
import {
  CoordinateInput,
  coordinatesToArray,
  createInitialCoordinates,
} from "@/components/CoordinateInput";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Card, CardContent } from "@/components/ui/card";

const DEFAULT_API_URL = "http://localhost:8080";

const modes: ApiMode[] = ["nearest", "route", "matrix"];

export default function Home() {
  const [mode, setMode] = useState<ApiMode>("route");
  const [apiUrl, setApiUrl] = useState(DEFAULT_API_URL);
  const [isLoading, setIsLoading] = useState(false);
  const [result, setResult] = useState<unknown>(null);
  const [error, setError] = useState<string | null>(null);
  const [coordinates, setCoordinates] = useState(() =>
    createInitialCoordinates(2)
  );
  const [options, setOptions] = useState<Record<string, boolean | string>>({
    steps: true,
    overview: "full",
  });

  const info = modeInfo[mode];

  // Reset coordinates when mode changes
  useEffect(() => {
    setResult(null);
    setError(null);
    setCoordinates(createInitialCoordinates(info.minCoordinates));
  }, [mode, info.minCoordinates]);

  const handleSubmit = async () => {
    const coords = coordinatesToArray(coordinates);

    if (!coords) {
      setError("Please enter valid coordinates (numbers only)");
      return;
    }

    if (coords.length < info.minCoordinates) {
      setError(`This mode requires at least ${info.minCoordinates} coordinate(s)`);
      return;
    }

    setIsLoading(true);
    setError(null);
    setResult(null);

    // Build request body based on mode
    let body: Record<string, unknown>;

    if (mode === "nearest") {
      body = { coordinate: coords[0] };
    } else {
      body = { coordinates: coords };

      // Add extra options for route mode
      if (mode === "route") {
        body.steps = options.steps;
        body.overview = options.overview;
        body.geometries = "geojson";
      }

      // Map match removed from UI; no special-case options here
    }

    try {
      const response = await fetch(`${apiUrl}/${mode}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const data = await response.json();

      if (!response.ok) {
        setError(data.error || data.message || `HTTP ${response.status}`);
      } else {
        setResult(data);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to connect to API");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <header className="border-b bg-card shrink-0">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-6">
            <h1 className="text-lg font-semibold">Geospatial API</h1>
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">API:</span>
              <input
                type="text"
                value={apiUrl}
                onChange={(e) => setApiUrl(e.target.value)}
                className="px-2 py-1 text-sm border rounded bg-background font-mono w-52"
              />
            </div>
          </div>
          <HealthIndicator apiUrl={apiUrl} />
        </div>
      </header>

      {/* Mode selector tabs */}
      <div className="border-b bg-card shrink-0">
        <div className="max-w-7xl mx-auto px-4">
          <div className="flex gap-1">
            {modes.map((m) => (
              <button
                key={m}
                onClick={() => setMode(m)}
                className={`px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
                  mode === m
                    ? "border-primary text-primary"
                    : "border-transparent text-muted-foreground hover:text-foreground"
                }`}
              >
                <span className="block">{modeInfo[m].title}</span>
                <span className="block text-xs font-normal opacity-70">
                  {modeInfo[m].shortDesc}
                </span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main content - horizontal layout */}
      <main className="flex-1 max-w-7xl mx-auto px-4 py-6 w-full">
        <div className="grid lg:grid-cols-[400px_1fr] gap-6 h-full">
          {/* Left: Input panel */}
          <div className="space-y-4">
            {/* Mode description */}
            <Card>
              <CardContent className="py-4">
                <p className="text-sm text-muted-foreground">{info.description}</p>
              </CardContent>
            </Card>

            {/* Coordinate inputs */}
            <Card>
              <CardContent className="py-4">
                <CoordinateInput
                  coordinates={coordinates}
                  onChange={setCoordinates}
                  minCoordinates={info.minCoordinates}
                  maxCoordinates={info.maxCoordinates}
                  singleMode={info.singleCoordinate}
                />
              </CardContent>
            </Card>

            {/* Extra options for route mode */}
            {mode === "route" && (
              <Card>
                <CardContent className="py-4">
                  <Label className="text-sm font-medium mb-3 block">Options</Label>
                  <div className="flex flex-wrap gap-4">
                    <label className="flex items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        checked={options.steps as boolean}
                        onChange={(e) =>
                          setOptions({ ...options, steps: e.target.checked })
                        }
                        className="rounded"
                      />
                      Turn-by-turn steps
                    </label>
                    <div className="flex items-center gap-2 text-sm">
                      <span>Detail:</span>
                      <select
                        value={options.overview as string}
                        onChange={(e) =>
                          setOptions({ ...options, overview: e.target.value })
                        }
                        className="px-2 py-1 border rounded bg-background text-sm"
                      >
                        <option value="full">Full</option>
                        <option value="simplified">Simplified</option>
                        <option value="false">None</option>
                      </select>
                    </div>
                  </div>
                </CardContent>
              </Card>
            )}

            {/* Submit button */}
            <Button
              onClick={handleSubmit}
              disabled={isLoading}
              className="w-full"
              size="lg"
            >
              {isLoading ? "Loading..." : `Get ${info.title}`}
            </Button>

            {/* Error display */}
            {error && (
              <div className="p-3 bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded-md">
                <p className="text-sm text-red-600 dark:text-red-400">{error}</p>
              </div>
            )}
          </div>

          {/* Right: Results panel */}
          <div className="min-h-[500px]">
            <ResultsDisplay mode={mode} data={result} error={null} />
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t shrink-0">
        <div className="max-w-7xl mx-auto px-4 py-3 text-center text-xs text-muted-foreground">
          Coordinates: [longitude, latitude] — e.g., [-123.12, 49.28] for Vancouver
        </div>
      </footer>
    </div>
  );
}
