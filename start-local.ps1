# =============================================================================
#   Geospatial Local Development - Start Everything (Windows)
#
#   Starts both:
#     - Backend API (Docker) on http://localhost:8080
#     - Frontend (Next.js) on http://localhost:3000
#
#   Prerequisites: Docker Desktop, Node.js (npm)
#   Usage: .\start-local.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Geospatial - Local Development" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ContainerName = "geospatial"
$ImageName = "geospatial:latest"
$DataDir = ".\data"
$BackendPort = 8080
$FrontendPort = 3000
$FrontendJob = $null

# Cleanup function
function Stop-Everything {
    Write-Host ""
    Write-Host "Shutting down..." -ForegroundColor Yellow

    # Stop frontend job
    if ($FrontendJob) {
        Stop-Job -Job $FrontendJob -ErrorAction SilentlyContinue
        Remove-Job -Job $FrontendJob -Force -ErrorAction SilentlyContinue
    }

    # Stop backend container
    docker stop $ContainerName 2>$null | Out-Null

    Write-Host "Done." -ForegroundColor Green
}

# Register cleanup on Ctrl+C
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Stop-Everything }

# -----------------------------------------------------------------------------
# Check prerequisites
# -----------------------------------------------------------------------------
Write-Host "[STEP] Checking prerequisites..." -ForegroundColor Blue

# Check Docker
$dockerCheck = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Check npm
$npmCheck = npm --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: npm is not installed. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Check data directory
if (-not (Test-Path $DataDir)) {
    Write-Host "ERROR: Data directory not found at $DataDir" -ForegroundColor Red
    Write-Host "Please create a 'data' folder with OSRM files. See README.md for setup."
    exit 1
}

$OsrmFile = Get-ChildItem -Path $DataDir -Filter "*.osrm" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $OsrmFile) {
    Write-Host "ERROR: No .osrm file found in $DataDir" -ForegroundColor Red
    Write-Host "Please download and preprocess OSRM data. See README.md for setup."
    exit 1
}
Write-Host "[INFO] Found OSRM data: $($OsrmFile.Name)" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Start Backend (Docker)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[STEP] Starting Backend API..." -ForegroundColor Blue

# Stop existing container if running
$running = docker ps -q -f "name=$ContainerName" 2>$null
if ($running) {
    Write-Host "[INFO] Stopping existing backend container..." -ForegroundColor Green
    docker stop $ContainerName | Out-Null
}

$exists = docker ps -aq -f "name=$ContainerName" 2>$null
if ($exists) {
    docker rm $ContainerName | Out-Null
}

# Build and run
Write-Host "[INFO] Building backend Docker image..." -ForegroundColor Green
docker build -t $ImageName -f backend/Dockerfile backend/ | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build Docker image" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Starting backend container..." -ForegroundColor Green
$AbsoluteDataDir = (Resolve-Path $DataDir).Path
docker run -d --name $ContainerName -p "${BackendPort}:8080" -v "${AbsoluteDataDir}:/data:ro" $ImageName | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to start container" -ForegroundColor Red
    exit 1
}

# Wait for backend to be ready
Write-Host "[INFO] Waiting for backend to be ready..." -ForegroundColor Green
$Retries = 60
for ($i = 1; $i -le $Retries; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$BackendPort/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "[INFO] Backend is ready!" -ForegroundColor Green
            break
        }
    } catch { }

    if ($i -eq $Retries) {
        Write-Host "ERROR: Backend did not start in time. Check: docker logs $ContainerName" -ForegroundColor Red
        exit 1
    }
    Start-Sleep -Seconds 1
}

# -----------------------------------------------------------------------------
# Start Frontend (Next.js)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[STEP] Starting Frontend..." -ForegroundColor Blue

Push-Location frontend

# Install dependencies if needed
if (-not (Test-Path "node_modules")) {
    Write-Host "[INFO] Installing frontend dependencies..." -ForegroundColor Green
    npm install | Out-Null
}

Write-Host "[INFO] Starting Next.js dev server..." -ForegroundColor Green

# Start frontend in a new process
$FrontendProcess = Start-Process -FilePath "npm" -ArgumentList "run", "dev" -PassThru -WindowStyle Hidden

Pop-Location

# Wait for frontend to be ready
Start-Sleep -Seconds 5
for ($i = 1; $i -le 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$FrontendPort" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            break
        }
    } catch { }
    Start-Sleep -Seconds 1
}

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Everything is running!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Frontend:  http://localhost:$FrontendPort" -ForegroundColor Cyan
Write-Host "  Backend:   http://localhost:$BackendPort" -ForegroundColor Cyan
Write-Host "  Health:    http://localhost:$BackendPort/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Press Ctrl+C to stop everything" -ForegroundColor Gray
Write-Host ""

# Keep script running and wait for Ctrl+C
try {
    while ($true) {
        # Check if frontend process is still running
        if ($FrontendProcess.HasExited) {
            Write-Host "Frontend process exited unexpectedly." -ForegroundColor Yellow
            break
        }
        Start-Sleep -Seconds 2
    }
} finally {
    # Cleanup
    if (-not $FrontendProcess.HasExited) {
        Stop-Process -Id $FrontendProcess.Id -Force -ErrorAction SilentlyContinue
    }
    docker stop $ContainerName 2>$null | Out-Null
    Write-Host "Stopped." -ForegroundColor Green
}
