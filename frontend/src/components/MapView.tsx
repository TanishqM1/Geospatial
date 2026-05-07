"use client";

import dynamic from "next/dynamic";
import { useMemo } from "react";

// Dynamically import the map component to avoid SSR issues with Leaflet
const MapViewInner = dynamic(() => import("./MapViewInner"), {
  ssr: false,
  loading: () => (
    <div className="h-[400px] w-full rounded-lg border bg-muted/30 flex items-center justify-center">
      <span className="text-muted-foreground">Loading map...</span>
    </div>
  ),
});

interface MapViewProps {
  markers?: { position: [number, number]; label?: string; color?: string }[];
  polyline?: [number, number][];
  matchedPoints?: [number, number][];
  center?: [number, number];
  zoom?: number;
}

export function MapView(props: MapViewProps) {
  return <MapViewInner {...props} />;
}
