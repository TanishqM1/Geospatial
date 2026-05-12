"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";

interface Coordinate {
  id: string;
  lon: string;
  lat: string;
}

interface CoordinateInputProps {
  coordinates: Coordinate[];
  onChange: (coordinates: Coordinate[]) => void;
  minCoordinates?: number;
  maxCoordinates?: number;
  singleMode?: boolean;
}

export function CoordinateInput({
  coordinates,
  onChange,
  minCoordinates = 1,
  maxCoordinates = 10,
  singleMode = false,
}: CoordinateInputProps) {
  const addCoordinate = () => {
    if (coordinates.length < maxCoordinates) {
      onChange([
        ...coordinates,
        { id: crypto.randomUUID(), lon: "", lat: "" },
      ]);
    }
  };

  const removeCoordinate = (id: string) => {
    if (coordinates.length > minCoordinates) {
      onChange(coordinates.filter((c) => c.id !== id));
    }
  };

  const updateCoordinate = (
    id: string,
    field: "lon" | "lat",
    value: string
  ) => {
    onChange(
      coordinates.map((c) => (c.id === id ? { ...c, [field]: value } : c))
    );
  };

  const getLabel = (index: number) => {
    if (singleMode) return "Location";
    if (index === 0) return "Start";
    if (index === coordinates.length - 1 && coordinates.length > 1) return "End";
    return `Stop ${index}`;
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <Label className="text-sm font-medium">
          Coordinates {!singleMode && `(${coordinates.length})`}
        </Label>
        {!singleMode && coordinates.length < maxCoordinates && (
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={addCoordinate}
          >
            + Add Point
          </Button>
        )}
      </div>

      <div className="space-y-2">
        {coordinates.map((coord, index) => (
          <div
            key={coord.id}
            className="p-3 bg-muted/30 rounded-md space-y-2"
          >
            <div className="flex items-center justify-between">
              <span className="text-xs font-medium text-muted-foreground">
                {getLabel(index)}
              </span>
              {!singleMode && coordinates.length > minCoordinates && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => removeCoordinate(coord.id)}
                  className="h-6 w-6 p-0 text-muted-foreground hover:text-destructive"
                >
                  ×
                </Button>
              )}
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs text-muted-foreground mb-1 block">Longitude</label>
                <input
                  type="text"
                  value={coord.lon}
                  onChange={(e) => updateCoordinate(coord.id, "lon", e.target.value)}
                  placeholder="-123.1207"
                  className="w-full px-3 py-2 text-sm border rounded bg-background font-mono"
                />
              </div>
              <div>
                <label className="text-xs text-muted-foreground mb-1 block">Latitude</label>
                <input
                  type="text"
                  value={coord.lat}
                  onChange={(e) => updateCoordinate(coord.id, "lat", e.target.value)}
                  placeholder="49.2827"
                  className="w-full px-3 py-2 text-sm border rounded bg-background font-mono"
                />
              </div>
            </div>
          </div>
        ))}
      </div>

      <p className="text-xs text-muted-foreground">
        Format: longitude first, then latitude (e.g., -123.1207, 49.2827 for Vancouver)
      </p>
    </div>
  );
}

export function coordinatesToArray(
  coordinates: Coordinate[]
): [number, number][] | null {
  const result: [number, number][] = [];

  for (const coord of coordinates) {
    const lon = parseFloat(coord.lon);
    const lat = parseFloat(coord.lat);

    if (isNaN(lon) || isNaN(lat)) {
      return null;
    }

    result.push([lon, lat]);
  }

  return result;
}

export function createInitialCoordinates(count: number): Coordinate[] {
  const defaults = [
    { lon: "-123.1207", lat: "49.2827" }, // Vancouver — Stanley Park
    { lon: "-122.8275", lat: "49.1117" }, // Surrey — Holland Park / Central City
    { lon: "-122.8490", lat: "49.1666" }, // Delta / Ladner
    { lon: "-122.7987", lat: "49.2820" }, // New Westminster
    { lon: "-123.3656", lat: "48.4284" }, // Victoria — BC Parliament Buildings
  ];

  return Array.from({ length: count }, (_, i) => ({
    id: crypto.randomUUID(),
    lon: defaults[i]?.lon || "",
    lat: defaults[i]?.lat || "",
  }));
}
