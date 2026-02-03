# Geospatial Routing Microservice (Kubernetes)

## Architecture

This project deploys a geospatial routing microservice using **Kubernetes sidecar pattern**:

- **Two containers in one Pod**:
  - `osrm` container: Runs OSRM routing engine (port 5000)
  - `flask` container: Runs Flask API proxy (port 8080)
- **Communication**: Both containers share the same network namespace, so Flask can reach OSRM via `localhost:5000`
- **Data**: Shared PersistentVolume mounted at `/data` containing preprocessed `.osrm` files

### Why Sidecar Pattern?

1. **Localhost communication**: Containers in the same Pod share network namespace
2. **Shared storage**: Both containers can access the same OSRM data files
3. **Atomic deployment**: Both services start/stop together
4. **Simplified networking**: No need for Service DNS or inter-pod networking

## Prerequisites

- Windows PC with Docker Desktop installed and running
- kubectl (Kubernetes CLI) - should already be installed
- minikube - installed by this project

## Quick Start

### 1. Run the setup script

```powershell
.\setup-k8s.ps1
```

This script will:
1. Check prerequisites
2. Start minikube cluster
3. Copy OSRM data to minikube VM
4. Build Flask Docker image
5. Pull OSRM image
6. Deploy to Kubernetes
7. Wait for pods to be ready

### 2. Get the service URL

```powershell
minikube service geospatial --url
```

### 3. Test the endpoint

```powershell
$url = minikube service geospatial --url
curl -X POST -H "Content-Type: application/json" `
  -d '{"coordinates":[[-123.3656,48.4284],[-123.1207,49.2827]]}' `
  "$url/matrix"
```

## Manual Deployment (Step-by-step)

If you prefer to run each step manually:

### 1. Start minikube

```powershell
minikube start --driver=docker --cpus=4 --memory=8192
```

### 2. Copy OSRM data to minikube

```powershell
minikube ssh "sudo mkdir -p /mnt/geospatial-data"
Get-ChildItem "data\british-columbia-251029.osrm*" | ForEach-Object {
    minikube cp $_.FullName "/mnt/geospatial-data/$($_.Name)"
}
```

### 3. Build images in minikube

```powershell
# Point Docker to minikube's daemon
minikube docker-env --shell powershell | Invoke-Expression

# Build Flask image
docker build -f Dockerfile.flask -t geospatial-flask:latest .

# Pull OSRM image
docker pull osrm/osrm-backend:latest
```

### 4. Deploy to Kubernetes

```powershell
kubectl apply -f k8s/pv-pvc.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 5. Wait for pods

```powershell
kubectl wait --for=condition=ready pod -l app=geospatial --timeout=120s
```

## Useful Commands

### View pod status
```powershell
kubectl get pods -l app=geospatial
kubectl describe pod -l app=geospatial
```

### View logs
```powershell
# OSRM logs
kubectl logs -l app=geospatial -c osrm

# Flask logs
kubectl logs -l app=geospatial -c flask

# Follow logs (live tail)
kubectl logs -f -l app=geospatial -c flask
```

### Get service URL
```powershell
minikube service geospatial --url
```

### Port forward (alternative access method)
```powershell
kubectl port-forward svc/geospatial 8080:80
# Then access at http://localhost:8080
```

### Restart deployment
```powershell
kubectl rollout restart deployment/geospatial
```

### Delete everything
```powershell
kubectl delete -f k8s/
```

### Stop minikube
```powershell
minikube stop
```

### Delete minikube cluster
```powershell
minikube delete
```

## Troubleshooting

### Pods not starting
```powershell
kubectl describe pod -l app=geospatial
kubectl logs -l app=geospatial -c osrm
kubectl logs -l app=geospatial -c flask
```

### OSRM data not found
- Ensure `.osrm` files are in the `data/` directory
- Check files were copied: `minikube ssh "ls -lh /mnt/geospatial-data"`

### Image pull errors
```powershell
# Re-configure Docker environment
minikube docker-env --shell powershell | Invoke-Expression

# Rebuild Flask image
docker build -f Dockerfile.flask -t geospatial-flask:latest .
```

### Cannot access service
```powershell
# Check service exists
kubectl get svc geospatial

# Check pods are ready
kubectl get pods -l app=geospatial

# Get service URL
minikube service geospatial --url
```

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│           Kubernetes Pod                │
│  ┌───────────────────────────────────┐  │
│  │  Network Namespace (localhost)    │  │
│  │                                   │  │
│  │  ┌──────────────┐ ┌────────────┐ │  │
│  │  │ OSRM         │ │ Flask      │ │  │
│  │  │ Container    │ │ Container  │ │  │
│  │  │              │ │            │ │  │
│  │  │ Port 5000 ◄──┼─┤ calls      │ │  │
│  │  │              │ │ localhost  │ │  │
│  │  └──────┬───────┘ └─────┬──────┘ │  │
│  └─────────┼───────────────┼────────┘  │
│            │               │           │
│            ▼               ▼           │
│     ┌──────────────────────────┐      │
│     │  Shared PersistentVolume │      │
│     │  /data/*.osrm files      │      │
│     └──────────────────────────┘      │
└─────────────────────────────────────────┘
              │
              ▼
       NodePort Service
              │
              ▼
         External Access
     (via minikube service)
```

## Files

- `Dockerfile.flask` - Flask-only container image
- `app.py` - Flask API (reads OSRM_URL from env)
- `k8s/pv-pvc.yaml` - PersistentVolume and PersistentVolumeClaim
- `k8s/deployment.yaml` - Pod with OSRM + Flask containers
- `k8s/service.yaml` - NodePort service for external access
- `setup-k8s.ps1` - Automated setup script

## Production Considerations

For production deployment:

1. **Use managed Kubernetes** (AKS, EKS, GKE)
2. **Separate data loading**: Use InitContainer or separate Job to preprocess OSM data
3. **Use proper storage**: Replace hostPath with cloud storage (Azure Files, EBS, GCS)
4. **Add Ingress**: Replace NodePort with Ingress controller + TLS
5. **Add monitoring**: Prometheus metrics, Grafana dashboards
6. **Set resource limits**: Tune CPU/memory based on load
7. **Add HPA**: Horizontal Pod Autoscaler for auto-scaling
8. **Security**: NetworkPolicies, RBAC, pod security standards
9. **Use ConfigMaps/Secrets**: For configuration and credentials
10. **Consider separation**: Split into separate Deployments if scaling independently
