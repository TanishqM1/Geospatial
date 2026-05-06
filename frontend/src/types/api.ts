export type ApiMode = "nearest" | "route" | "matrix" | "match";

export interface NearestRequest {
  coordinate: [number, number];
}

export interface NearestResponse {
  name: string;
  location: [number, number];
  distance: number;
}

export interface RouteRequest {
  coordinates: [number, number][];
  steps?: boolean;
  geometries?: "geojson" | "polyline";
  overview?: "full" | "simplified" | "false";
}

export interface RouteStep {
  instruction: string;
  distance: number;
  duration: number;
  name: string;
  maneuver: {
    type: string;
    modifier?: string;
    location: [number, number];
  };
}

export interface RouteResponse {
  distance: number;
  duration: number;
  geometry: GeoJSON.LineString | string;
  steps?: RouteStep[];
}

export interface MatrixRequest {
  coordinates: [number, number][];
}

export interface MatrixResponse {
  distances: number[][];
  durations: number[][];
}

export interface MatchRequest {
  coordinates: [number, number][];
  timestamps?: number[];
  radiuses?: number[];
}

export interface MatchResponse {
  confidence: number;
  matched_coordinates: [number, number][];
  geometry: GeoJSON.LineString | string;
}

export interface HealthResponse {
  status: "healthy" | "unhealthy";
}

export interface ApiError {
  error: string;
  message?: string;
}
