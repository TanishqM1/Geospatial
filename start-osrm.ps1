# =============================================================================
#   Geospatial OSRM Startup Script (Windows)
#
#   This script starts the entire geospatial routing service using Docker.
#   Prerequisites: Docker Desktop installed and running
#
#   Usage: .\start-osrm.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Geospatial Routing API - Starting..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Configuration
$ContainerName = "geospatial"
$ImageName = "geospatial:latest"
$DataDir = ".\data"
$Port = 8080

# Check Docker is running
try {
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host "ERROR: Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Check data directory exists
if (-not (Test-Path $DataDir)) {
    Write-Host "ERROR: Data directory not found at $DataDir" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please create a 'data' folder with OSRM files. See README.md for setup instructions."
    exit 1
}

# Check for .osrm files
$OsrmFiles = Get-ChildItem -Path $DataDir -Filter "*.osrm" -ErrorAction SilentlyContinue
if (-not $OsrmFiles) {
    Write-Host "ERROR: No .osrm files found in $DataDir" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download and preprocess OSRM data. See README.md for instructions."
    exit 1
}

# Stop existing container if running
$running = docker ps -q -f "name=$ContainerName" 2>$null
if ($running) {
    Write-Host "Stopping existing container..."
    docker stop $ContainerName > $null
}

# Remove existing container if exists
$exists = docker ps -aq -f "name=$ContainerName" 2>$null
if ($exists) {
    Write-Host "Removing existing container..."
    docker rm $ContainerName > $null
}

# Build image
Write-Host ""
Write-Host "[1/2] Building Docker image..." -ForegroundColor Yellow
docker build -t $ImageName -f Dockerfile .
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build Docker image" -ForegroundColor Red
    exit 1
}

# Run container
Write-Host ""
Write-Host "[2/2] Starting container..." -ForegroundColor Yellow
$AbsoluteDataDir = (Resolve-Path $DataDir).Path
docker run -d `
    --name $ContainerName `
    -p "${Port}:8080" `
    -v "${AbsoluteDataDir}:/data:ro" `
    $ImageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to start container" -ForegroundColor Red
    exit 1
}

# Wait for service to be ready
Write-Host ""
Write-Host "Waiting for service to start..." -NoNewline
$Retries = 30
for ($i = 1; $i -le $Retries; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host ""
            Write-Host ""
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "  Service is ready!" -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "  API:    http://localhost:$Port" -ForegroundColor Cyan
            Write-Host "  Health: http://localhost:$Port/health" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Test with:" -ForegroundColor Yellow
            Write-Host "    Invoke-WebRequest -Uri 'http://localhost:$Port/nearest' ``"
            Write-Host "      -Method POST -ContentType 'application/json' ``"
            Write-Host "      -Body '{`"coordinate`": [-123.1207, 49.2827]}'"
            Write-Host ""
            Write-Host "  View logs:" -ForegroundColor Yellow
            Write-Host "    docker logs -f $ContainerName"
            Write-Host ""
            Write-Host "  Stop:" -ForegroundColor Yellow
            Write-Host "    docker stop $ContainerName"
            Write-Host ""
            exit 0
        }
    } catch {
        # Service not ready yet
    }
    Start-Sleep -Seconds 1
    Write-Host "." -NoNewline
}

Write-Host ""
Write-Host "WARNING: Service did not become ready in $Retries seconds." -ForegroundColor Yellow
Write-Host "Check logs: docker logs $ContainerName"
exit 1
