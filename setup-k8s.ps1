# Geospatial Kubernetes Setup Script for Windows
$ErrorActionPreference = "Stop"

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Geospatial K8s Setup (Windows)" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Check prerequisites
Write-Host "`n[1/8] Checking prerequisites..." -ForegroundColor Yellow
$minikubePath = "$env:USERPROFILE\bin\minikube.exe"
if (-not (Test-Path $minikubePath)) {
    Write-Host "ERROR: minikube not found" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Prerequisites found" -ForegroundColor Green

# Start minikube
Write-Host "`n[2/8] Starting minikube..." -ForegroundColor Yellow
& $minikubePath start --driver=docker --cpus=2 --memory=6144
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to start minikube" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Minikube started" -ForegroundColor Green

# Copy data
Write-Host "`n[3/8] Copying OSRM data..." -ForegroundColor Yellow
$sshResult = & $minikubePath ssh "sudo mkdir -p /mnt/geospatial-data" 2>&1
$dataFiles = Get-ChildItem "data\british-columbia-251029.osrm*"
foreach ($file in $dataFiles) {
    Write-Host "  Copying $($file.Name)..."
    $cpResult = & $minikubePath cp $file.FullName "/mnt/geospatial-data/$($file.Name)" 2>&1
}
Write-Host "OK: Data copied" -ForegroundColor Green

# Configure Docker
Write-Host "`n[4/8] Configuring Docker..." -ForegroundColor Yellow
$dockerEnvOutput = & $minikubePath docker-env --shell powershell 2>&1
if ($LASTEXITCODE -eq 0) {
    $dockerEnvOutput | Invoke-Expression
    Write-Host "OK: Docker configured" -ForegroundColor Green
} else {
    Write-Host "WARNING: Could not configure Docker env" -ForegroundColor Yellow
}

# Build Flask image
Write-Host "`n[5/8] Building Flask image..." -ForegroundColor Yellow
docker build -f Dockerfile.flask -t geospatial-flask:latest .
Write-Host "OK: Image built" -ForegroundColor Green

# Pull OSRM image
Write-Host "`n[6/8] Pulling OSRM image..." -ForegroundColor Yellow
docker pull osrm/osrm-backend:latest
Write-Host "OK: Image pulled" -ForegroundColor Green

# Deploy
Write-Host "`n[7/8] Deploying to Kubernetes..." -ForegroundColor Yellow
kubectl apply -f k8s/pv-pvc.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
Write-Host "OK: Deployed" -ForegroundColor Green

# Wait for pods
Write-Host "`n[8/8] Waiting for pods..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=geospatial --timeout=120s
Write-Host "OK: Pods ready!" -ForegroundColor Green

# Show status
Write-Host "`n=================================="-ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Cyan
Write-Host "=================================="-ForegroundColor Cyan
kubectl get pods -l app=geospatial
kubectl get svc geospatial

Write-Host "`nGet service URL:" -ForegroundColor Yellow
Write-Host "  minikube service geospatial --url" -ForegroundColor Cyan

Write-Host "`nView logs:" -ForegroundColor Yellow
Write-Host "  kubectl logs -l app=geospatial -c osrm" -ForegroundColor Cyan
Write-Host "  kubectl logs -l app=geospatial -c flask" -ForegroundColor Cyan
