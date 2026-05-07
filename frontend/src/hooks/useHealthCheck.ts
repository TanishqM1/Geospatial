"use client";

import { useState, useEffect, useCallback } from "react";
import { HealthResponse } from "@/types/api";

interface UseHealthCheckResult {
  isHealthy: boolean | null;
  lastChecked: Date | null;
  error: string | null;
}

export function useHealthCheck(
  apiUrl: string,
  intervalMs: number = 30000
): UseHealthCheckResult {
  const [isHealthy, setIsHealthy] = useState<boolean | null>(null);
  const [lastChecked, setLastChecked] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);

  const checkHealth = useCallback(async () => {
    try {
      const response = await fetch(`${apiUrl}/health`, {
        method: "GET",
        signal: AbortSignal.timeout(5000),
      });

      if (response.ok) {
        const data: HealthResponse = await response.json();
        setIsHealthy(data.status === "healthy");
        setError(null);
      } else {
        setIsHealthy(false);
        setError(`HTTP ${response.status}`);
      }
    } catch {
      setIsHealthy(false);
      setError("Connection failed");
    }
    setLastChecked(new Date());
  }, [apiUrl]);

  useEffect(() => {
    checkHealth();
    const interval = setInterval(checkHealth, intervalMs);
    return () => clearInterval(interval);
  }, [checkHealth, intervalMs]);

  return { isHealthy, lastChecked, error };
}
