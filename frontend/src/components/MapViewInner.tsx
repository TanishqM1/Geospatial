"use client";

import { useMemo, useEffect, useState } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Polyline,
  CircleMarker,
  Popup,
  useMap,
} from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

// Fix default marker icon
const defaultIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

interface MapViewInnerProps {
  markers?: { position: [number, number]; label?: string; color?: string }[];
  polyline?: [number, number][];
  matchedPoints?: [number, number][];
  center?: [number, number];
  zoom?: number;
}

function FitBounds({
  bounds,
}: {
  bounds: L.LatLngBoundsExpression | undefined;
}) {
  const map = useMap();

  useEffect(() => {
    if (bounds) {
      map.fitBounds(bounds, { padding: [50, 50] });
    }
  }, [map, bounds]);

  return null;
}

export default function MapViewInner({
  markers = [],
  polyline,
  matchedPoints,
  center = [49.2827, -123.1207],
  zoom = 12,
}: MapViewInnerProps) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const bounds = useMemo(() => {
    const allPoints: [number, number][] = [];

    markers.forEach((m) => allPoints.push(m.position));
    if (polyline) allPoints.push(...polyline);
    if (matchedPoints) allPoints.push(...matchedPoints);

    if (allPoints.length < 2) return undefined;

    return L.latLngBounds(allPoints.map((p) => [p[0], p[1]]));
  }, [markers, polyline, matchedPoints]);

  if (!mounted) {
    return (
      <div className="h-[400px] w-full rounded-lg border bg-muted/30 flex items-center justify-center">
        <span className="text-muted-foreground">Loading map...</span>
      </div>
    );
  }

  return (
    <div className="h-[400px] w-full rounded-lg overflow-hidden border">
      <MapContainer
        center={center}
        zoom={zoom}
        className="h-full w-full"
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        <FitBounds bounds={bounds} />

        {markers.map((marker, idx) => (
          <Marker key={idx} position={marker.position} icon={defaultIcon}>
            {marker.label && <Popup>{marker.label}</Popup>}
          </Marker>
        ))}

        {polyline && polyline.length > 1 && (
          <Polyline
            positions={polyline}
            color="blue"
            weight={4}
            opacity={0.7}
          />
        )}

        {matchedPoints?.map((point, idx) => (
          <CircleMarker
            key={`matched-${idx}`}
            center={point}
            radius={6}
            color="green"
            fillColor="green"
            fillOpacity={0.8}
          >
            <Popup>Matched point {idx + 1}</Popup>
          </CircleMarker>
        ))}
      </MapContainer>
    </div>
  );
}
