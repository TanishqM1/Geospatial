# Quick Reference - Geospatial K8s

## ✅ Verified Working Setup

Your OSRM + Flask microservice is now running in Kubernetes with:
- **Two separate containers** (OSRM and Flask) in one Pod
- **Localhost communication** inside the Pod (Flask calls `http://127.0.0.1:5000`)
- Successfully tested with distance matrix query

---

## Daily Usage Commands

### Start Everything (if stopped)
```powershell
minikube start
kubectl port-forward svc/geospatial 8080:80
```
Keep the port-forward terminal open.

### Test the Service
```powershell
$body = '{"coordinates":[[-123.3656,48.4284],[-123.1207,49.2827]]}'
Invoke-WebRequest -Uri http://localhost:8080/matrix -Method POST -ContentType "application/json" -Body $body -UseBasicParsing | Select-Object -ExpandProperty Content
```

### View Logs
```powershell
# OSRM logs
kubectl logs -l app=geospatial -c osrm --tail=50 -f

# Flask logs  
kubectl logs -l app=geospatial -c flask --tail=50 -f
```

### Check Status
```powershell
kubectl get pods -l app=geospatial
kubectl get svc geospatial
kubectl describe pod -l app=geospatial
```

### Restart the Service
```powershell
kubectl rollout restart deployment/geospatial
```

### Stop Everything
```powershell
# Stop port-forward (Ctrl+C in that terminal)
# Stop minikube
minikube stop
```

---

## Architecture Summary

```
┌─────────────────────────────────────┐
│         Kubernetes Pod              │
│  ┌──────────────────────────────┐   │
│  │  Shared Network (localhost)  │   │
│  │                              │   │
│  │  ┌─────────┐   ┌──────────┐ │   │
│  │  │ OSRM    │◄──┤  Flask   │ │   │
│  │  │ :5000   │   │  :8080   │ │   │
│  │  └─────────┘   └──────────┘ │   │
│  └──────────────────────────────┘   │
│            ▼                        │
│  ┌──────────────────────┐          │
│  │ PersistentVolume     │          │
│  │ /data/*.osrm files   │          │
│  └──────────────────────┘          │
└─────────────────────────────────────┘
               │
               ▼
        NodePort Service
               │
               ▼
      kubectl port-forward
               │
               ▼
      http://localhost:8080
```

---

## Files Created

- `Dockerfile.flask` - Flask-only container
- `k8s/pv-pvc.yaml` - Storage for OSRM data
- `k8s/deployment.yaml` - Pod with both containers
- `k8s/service.yaml` - NodePort service
- `setup-k8s.ps1` - Automated setup script
- `README-K8S.md` - Full documentation
- `QUICKREF.md` - This file

---

## Troubleshooting

### Pod not starting
```powershell
kubectl describe pod -l app=geospatial
kubectl logs -l app=geospatial -c osrm
kubectl logs -l app=geospatial -c flask
```

### Cannot access service
```powershell
# Check port-forward is running
# Re-run: kubectl port-forward svc/geospatial 8080:80
```

### Data not found error
```powershell
# Check data was copied
minikube ssh "ls -lh /mnt/geospatial-data"
```

### Rebuild and redeploy
```powershell
# Point to minikube Docker
minikube docker-env --shell powershell | Invoke-Expression

# Rebuild
docker build -f Dockerfile.flask -t geospatial-flask:latest .

# Restart
kubectl rollout restart deployment/geospatial
```
