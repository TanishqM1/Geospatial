"use client";

import { useHealthCheck } from "@/hooks/useHealthCheck";

interface HealthIndicatorProps {
  apiUrl: string;
}

export function HealthIndicator({ apiUrl }: HealthIndicatorProps) {
  const { isHealthy, lastChecked, error } = useHealthCheck(apiUrl, 30000);

  const getStatusColor = () => {
    if (isHealthy === null) return "bg-yellow-500";
    return isHealthy ? "bg-green-500" : "bg-red-500";
  };

  const getStatusText = () => {
    if (isHealthy === null) return "Checking...";
    if (isHealthy) return "Connected";
    return error || "Disconnected";
  };

  return (
    <div className="flex items-center gap-2 text-sm text-muted-foreground">
      <div
        className={`w-2.5 h-2.5 rounded-full ${getStatusColor()} animate-pulse`}
        title={getStatusText()}
      />
      <span className="hidden sm:inline">{getStatusText()}</span>
      {lastChecked && (
        <span className="hidden md:inline text-xs">
          (checked {lastChecked.toLocaleTimeString()})
        </span>
      )}
    </div>
  );
}
