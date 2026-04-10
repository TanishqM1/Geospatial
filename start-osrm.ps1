# =============================================================================
#   Geospatial OSRM Startup Script (Windows)
#
#   Prerequisites: Docker Desktop installed and running
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
$dockerCheck = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Check data directory exists
if (-not (Test-Path $DataDir)) {
    Write-Host "ERROR: Data directory not found at $DataDir" -ForegroundColor Red
    Write-Host "Please create a 'data' folder with OSRM files. See README.md for setup instructions."
    exit 1
}

# Check for any .osrm file
$OsrmFile = Get-ChildItem -Path $DataDir -Filter "*.osrm" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $OsrmFile) {
    Write-Host "ERROR: No .osrm file found in $DataDir" -ForegroundColor Red
    Write-Host "Please download and preprocess OSRM data. See README.md for setup instructions."
    exit 1
}
Write-Host "Found OSRM data: $($OsrmFile.Name)" -ForegroundColor Green

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
docker build -t $ImageName -f backend/Dockerfile backend/
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build Docker image" -ForegroundColor Red
    exit 1
}

# Run container
Write-Host ""
Write-Host "[2/2] Starting container..." -ForegroundColor Yellow
$AbsoluteDataDir = (Resolve-Path $DataDir).Path
docker run -d --name $ContainerName -p "${Port}:8080" -v "${AbsoluteDataDir}:/data:ro" $ImageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to start container" -ForegroundColor Red
    exit 1
}

# Wait for service to be ready
Write-Host ""
Write-Host "Waiting for service to start..." -NoNewline
$Retries = 60
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
            Write-Host "  View logs:  docker logs -f $ContainerName" -ForegroundColor Gray
            Write-Host "  Stop:       docker stop $ContainerName" -ForegroundColor Gray
            Write-Host ""
            exit 0
        }
    } catch { }
    Start-Sleep -Seconds 1
    Write-Host "." -NoNewline
}

Write-Host ""
Write-Host "WARNING: Service did not become ready in $Retries seconds." -ForegroundColor Yellow
Write-Host "Check logs: docker logs $ContainerName"
exit 1
