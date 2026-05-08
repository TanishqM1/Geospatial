# ===================================================
#   Flask + OSRM (multi-stage build, self-contained)
# ===================================================

# --- Stage 1: Pull OSRM binaries and libs (force amd64 for compatibility) ---
FROM --platform=linux/amd64 osrm/osrm-backend:latest AS osrm

# --- Stage 2: Python + Flask runtime (match amd64 platform) ---
FROM --platform=linux/amd64 python:3.10-slim

# Install runtime dependencies (Boost, Protobuf, TBB, ICU)
RUN apt-get update && \
    apt-get install -y \
        bash curl \
        libboost-program-options-dev \
        libprotobuf-dev \
        libstdc++6 \
        libtbb12 \
        libicu-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Compatibility symlinks for older OSRM-linked libs ---
# OSRM expects old SONAMEs (Boost/TBB/ICU from Ubuntu 16.04)
RUN ln -sf /usr/lib/x86_64-linux-gnu/libtbb.so.12  /usr/lib/x86_64-linux-gnu/libtbb.so.2  || true && \
    ln -sf /usr/lib/x86_64-linux-gnu/libicudata.so.76  /usr/lib/x86_64-linux-gnu/libicudata.so.57 || true && \
    ln -sf /usr/lib/x86_64-linux-gnu/libicuuc.so.76    /usr/lib/x86_64-linux-gnu/libicuuc.so.57   || true && \
    ln -sf /usr/lib/x86_64-linux-gnu/libicui18n.so.76  /usr/lib/x86_64-linux-gnu/libicui18n.so.57 || true

# Ensure /lib64 exists and provide the x86_64 dynamic loader path expected by some OSRM binaries
RUN mkdir -p /lib64 && ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2 || true

# --- Copy OSRM binaries and shared libs from Stage 1 ---
COPY --from=osrm /usr/local/bin/osrm* /usr/local/bin/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libboost*   /usr/lib/x86_64-linux-gnu/
COPY --from=osrm /usr/lib/x86_64-linux-gnu/libprotobuf* /usr/lib/x86_64-linux-gnu/

# --- Setup Flask app ---
WORKDIR /app
COPY app.py requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy a simple startup script that launches OSRM then the Flask app
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# --- Expose ports ---
EXPOSE 8080 5000
VOLUME ["/data"]

# --- Healthcheck (optional but useful) ---
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD curl -fs http://localhost:8080/ || curl -fs http://localhost:5000/ || exit 1

# --- Start OSRM + Flask ---
CMD ["bash", "/app/start.sh"]
