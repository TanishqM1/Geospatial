"use client";

import { Card, CardContent } from "@/components/ui/card";

interface JsonViewerProps {
  data: unknown;
  title?: string;
}

export function JsonViewer({ data, title }: JsonViewerProps) {
  return (
    <Card>
      {title && (
        <div className="px-4 py-2 border-b bg-muted/50">
          <h3 className="font-medium text-sm">{title}</h3>
        </div>
      )}
      <CardContent className="p-0">
        <pre className="p-4 text-sm overflow-auto max-h-[400px] bg-muted/30 font-mono">
          {JSON.stringify(data, null, 2)}
        </pre>
      </CardContent>
    </Card>
  );
}
