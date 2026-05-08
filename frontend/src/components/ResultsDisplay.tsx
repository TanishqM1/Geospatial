"use client";

import { ApiMode } from "@/types/api";
import { MapView } from "@/components/MapView";
import { JsonViewer } from "@/components/JsonViewer";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

interface ResultsDisplayProps {
  mode: ApiMode;
  data: unknown;
  error?: string | null;
}

export function ResultsDisplay({ mode, data, error }: ResultsDisplayProps) {
  if (error) {
    return (
      <Card className="border-red-200 dark:border-red-800">
        <CardHeader className="pb-2">
          <CardTitle className="text-lg text-red-600 dark:text-red-400">
            Error
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-red-600 dark:text-red-400">{error}</p>
        </CardContent>
      </Card>
    );
  }

  if (!data) {
    return (
      <Card className="border-dashed">
        <CardContent className="py-8 text-center text-muted-foreground">
          Send a request to see results here
        </CardContent>
      </Card>
    );
  }

  const mapData = extractMapData(mode, data);

  return (
    <Tabs defaultValue="map" className="w-full">
      <TabsList className="grid w-full grid-cols-2">
        <TabsTrigger value="map">Map</TabsTrigger>
        <TabsTrigger value="json">JSON Response</TabsTrigger>
      </TabsList>

      <TabsContent value="map" className="mt-4">
        {mapData.hasMapData ? (
          <MapView
            markers={mapData.markers}
            polyline={mapData.polyline}
            matchedPoints={mapData.matchedPoints}
            center={mapData.center}
          />
        ) : (
          <Card className="border-dashed">
            <CardContent className="py-8 text-center text-muted-foreground">
              {mode === "matrix"
                ? "Matrix results are shown as a table below"
                : "No geographic data to display"}
            </CardContent>
          </Card>
        )}

        {mode === "matrix" && data && <MatrixTable data={data} />}
        {mode === "route" && data && <RouteSummary data={data} />}
        {mode === "match" && data && <MatchSummary data={data} />}
        {mode === "nearest" && data && <NearestSummary data={data} />}
      </TabsContent>

      <TabsContent value="json" className="mt-4">
        <JsonViewer data={data} title="API Response" />
      </TabsContent>
    </Tabs>
  );
}

function extractMapData(mode: ApiMode, data: unknown) {
  const result: {
    hasMapData: boolean;
    markers: { position: [number, number]; label?: string }[];
    polyline?: [number, number][];
    matchedPoints?: [number, number][];
    center?: [number, number];
  } = {
    hasMapData: false,
    markers: [],
  };

  const d = data as Record<string, unknown>;

  if (mode === "nearest" && d.location) {
    const loc = d.location as [number, number];
    result.markers.push({
      position: [loc[1], loc[0]], // Flip lon/lat to lat/lon
      label: (d.name as string) || "Nearest point",
    });
    result.center = [loc[1], loc[0]];
    result.hasMapData = true;
  }

  if (mode === "route" && d.geometry) {
    const geom = d.geometry as { coordinates?: [number, number][] };
    if (geom.coordinates) {
      result.polyline = geom.coordinates.map((c) => [c[1], c[0]]); // Flip to lat/lon
      if (result.polyline.length > 0) {
        result.markers.push({
          position: result.polyline[0],
          label: "Start",
        });
        result.markers.push({
          position: result.polyline[result.polyline.length - 1],
          label: "End",
        });
        result.center = result.polyline[0];
        result.hasMapData = true;
      }
    }
  }

  if (mode === "match") {
    if (d.matched_coordinates) {
      const coords = d.matched_coordinates as [number, number][];
      result.matchedPoints = coords.map((c) => [c[1], c[0]]); // Flip to lat/lon
      if (result.matchedPoints.length > 0) {
        result.center = result.matchedPoints[0];
        result.hasMapData = true;
      }
    }
    if (d.geometry) {
      const geom = d.geometry as { coordinates?: [number, number][] };
      if (geom.coordinates) {
        result.polyline = geom.coordinates.map((c) => [c[1], c[0]]);
        result.hasMapData = true;
      }
    }
  }

  return result;
}

function MatrixTable({ data }: { data: unknown }) {
  const d = data as { distances?: number[][]; durations?: number[][] };
  if (!d.distances || !d.durations) return null;

  return (
    <div className="mt-4 space-y-4">
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm">Distances (meters)</CardTitle>
        </CardHeader>
        <CardContent className="overflow-auto">
          <table className="w-full text-sm">
            <tbody>
              {d.distances.map((row, i) => (
                <tr key={i}>
                  {row.map((val, j) => (
                    <td
                      key={j}
                      className="border px-2 py-1 text-center font-mono"
                    >
                      {val?.toFixed(0) ?? "-"}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm">Durations (seconds)</CardTitle>
        </CardHeader>
        <CardContent className="overflow-auto">
          <table className="w-full text-sm">
            <tbody>
              {d.durations.map((row, i) => (
                <tr key={i}>
                  {row.map((val, j) => (
                    <td
                      key={j}
                      className="border px-2 py-1 text-center font-mono"
                    >
                      {val?.toFixed(0) ?? "-"}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </CardContent>
      </Card>
    </div>
  );
}

function RouteSummary({ data }: { data: unknown }) {
  type RouteStep = {
    instruction?: string;
    distance: number;
    duration?: number;
    name?: string;
    maneuver?: {
      type?: string;
      modifier?: string;
    };
  };

  const d = data as {
    distance?: number;
    duration?: number;
    steps?: RouteStep[];
    routes?: {
      legs?: {
        steps?: RouteStep[];
      }[];
    }[];
  };

  const fallbackLegSteps =
    d.routes?.[0]?.legs?.flatMap((leg) => leg.steps ?? []) ?? [];
  const steps = d.steps && d.steps.length > 0 ? d.steps : fallbackLegSteps;

  const formatStepInstruction = (step: RouteStep) => {
    if (step.instruction && step.instruction.trim().length > 0) {
      return step.instruction;
    }

    const mType = step.maneuver?.type?.trim().toLowerCase();
    const modifier = step.maneuver?.modifier?.trim().toLowerCase();
    const road = step.name && step.name.trim().length > 0 ? ` onto ${step.name.trim()}` : "";

    if (mType === "depart") {
      if (modifier) {
        return `Depart and head ${modifier}${road}`;
      }
      return `Depart${road}`;
    }

    if (mType === "arrive") {
      return "Arrive at destination";
    }

    if (mType === "turn") {
      if (modifier) {
        return `${capitalize(modifier)} turn${road}`;
      }
      return `Turn${road}`;
    }

    if (mType === "continue") {
      return `Continue${road}`;
    }

    if (mType === "fork") {
      return `${modifier ? capitalize(modifier) + " fork" : "Take the fork"}${road}`;
    }

    if (mType === "merge") {
      return `${modifier ? "Merge " + modifier : "Merge"}${road}`;
    }

    if (modifier) {
      return `${capitalize(modifier)}${road}`;
    }

    return road ? `Continue${road}` : "Continue";
  };

  return (
    <Card className="mt-4">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Route Summary</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        <div className="flex gap-4 text-sm">
          <div>
            <span className="text-muted-foreground">Distance:</span>{" "}
            <strong>{((d.distance ?? 0) / 1000).toFixed(2)} km</strong>
          </div>
          <div>
            <span className="text-muted-foreground">Duration:</span>{" "}
            <strong>{Math.round((d.duration ?? 0) / 60)} min</strong>
          </div>
        </div>

        {steps.length > 0 && (
          <div className="mt-3">
            <p className="text-sm font-medium mb-2">Turn-by-turn:</p>
            <div className="max-h-[200px] overflow-auto space-y-1">
              {steps.map((step, i) => (
                <div
                  key={i}
                  className="text-xs p-2 bg-muted/50 rounded flex justify-between"
                >
                  <span>
                    {i + 1}. {formatStepInstruction(step)}
                  </span>
                  <span className="text-muted-foreground">
                    {(step.distance / 1000).toFixed(2)} km
                    {step.duration != null ? `, ${Math.round(step.duration)}s` : ""}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function capitalize(value: string) {
  if (!value) return value;
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function MatchSummary({ data }: { data: unknown }) {
  const d = data as {
    confidence?: number;
    matched_coordinates?: [number, number][];
  };

  return (
    <Card className="mt-4">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Match Summary</CardTitle>
      </CardHeader>
      <CardContent className="text-sm">
        <div>
          <span className="text-muted-foreground">Confidence:</span>{" "}
          <strong>{((d.confidence ?? 0) * 100).toFixed(1)}%</strong>
        </div>
        <div>
          <span className="text-muted-foreground">Points matched:</span>{" "}
          <strong>{d.matched_coordinates?.length ?? 0}</strong>
        </div>
      </CardContent>
    </Card>
  );
}

function NearestSummary({ data }: { data: unknown }) {
  const d = data as {
    name?: string;
    distance?: number;
    location?: [number, number];
  };

  return (
    <Card className="mt-4">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Nearest Road</CardTitle>
      </CardHeader>
      <CardContent className="text-sm space-y-1">
        <div>
          <span className="text-muted-foreground">Street:</span>{" "}
          <strong>{d.name || "Unknown"}</strong>
        </div>
        <div>
          <span className="text-muted-foreground">Distance from input:</span>{" "}
          <strong>{d.distance?.toFixed(1) ?? "-"} m</strong>
        </div>
        {d.location && (
          <div>
            <span className="text-muted-foreground">Snapped location:</span>{" "}
            <code className="text-xs">
              [{d.location[0].toFixed(6)}, {d.location[1].toFixed(6)}]
            </code>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
