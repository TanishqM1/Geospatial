import { ApiMode } from "@/types/api";

interface ModeInfo {
  title: string;
  shortDesc: string;
  description: string;
  minCoordinates: number;
  maxCoordinates: number;
  singleCoordinate: boolean;
  extraOptions: {
    name: string;
    type: "boolean" | "select";
    options?: string[];
    default: boolean | string;
    description: string;
  }[];
}

export const modeInfo: Record<ApiMode, ModeInfo> = {
  nearest: {
    title: "Nearest Road",
    shortDesc: "Find closest road to a point",
    description: "Snaps a coordinate to the nearest point on the road network. Useful for validating addresses or finding drivable locations.",
    minCoordinates: 1,
    maxCoordinates: 1,
    singleCoordinate: true,
    extraOptions: [],
  },
  route: {
    title: "Route",
    shortDesc: "Get driving directions A → B",
    description: "Calculate the fastest driving route between two or more points. Returns distance, time, and turn-by-turn directions.",
    minCoordinates: 2,
    maxCoordinates: 10,
    singleCoordinate: false,
    extraOptions: [
      {
        name: "steps",
        type: "boolean",
        default: true,
        description: "Include turn-by-turn instructions",
      },
      {
        name: "overview",
        type: "select",
        options: ["full", "simplified", "false"],
        default: "full",
        description: "Route geometry detail level",
      },
    ],
  },
  matrix: {
    title: "Matrix",
    shortDesc: "Distance between all point pairs",
    description: "Compute driving distances and times between every pair of locations. Great for finding the closest option or optimizing delivery routes.",
    minCoordinates: 2,
    maxCoordinates: 10,
    singleCoordinate: false,
    extraOptions: [],
  },
  match: {
    title: "Map Match",
    shortDesc: "Snap GPS trace to roads",
    description: "Correct GPS drift by snapping a sequence of recorded points to the actual roads traveled. Used for cleaning up GPS tracks.",
    minCoordinates: 2,
    maxCoordinates: 50,
    singleCoordinate: false,
    extraOptions: [],
  },
};
