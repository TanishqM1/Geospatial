# Geospatial Routing Microservice (Kubernetes)

This document covers two Kubernetes deployment options:

| Deployment | Folder | Use Case |
|------------|--------|----------|
| **Local Development** | `backend/k8s/` | Quick testing with Minikube |
| **Production** | `k8s-prod/` | Production-ready backend API with HA, auto-scaling, security |

> **Note:** The frontend (`frontend/`) is for local demo purposes only. It is NOT deployed in production.

---

# Option 1: Local Development (Minikube)

Simple setup for testing the backend API on your local machine.

## Quick Start

**Windows (PowerShell):**
```powershell
.\setup-k8s.ps1
```

**Manual:**
```bash
# 1. Start minikube
minikube start --driver=docker --cpus=4 --memory=8192

# 2. Copy OSRM data to minikube
minikube ssh "sudo mkdir -p /mnt/geospatial-data"
# Copy your .osrm files to /mnt/geospatial-data

# 3. Build images in minikube
eval $(minikube docker-env)
docker build -f backend/Dockerfile.flask -t geospatial-flask:latest backend/

# 4. Deploy
kubectl apply -f backend/k8s/

# 5. Get URL
minikube service geospatial --url
```

## Local Files

| File | Purpose |
|------|---------|
| `backend/k8s/pv-pvc.yaml` | PersistentVolume (hostPath for Minikube) |
| `backend/k8s/deployment.yaml` | Single pod with OSRM + Flask containers |
| `backend/k8s/service.yaml` | NodePort service |

---

# Option 2: Production Deployment

Production-ready backend API deployment for cloud Kubernetes (EKS, GKE, AKS).

## Quick Start

```bash
# Deploy to production cluster
./deploy-prod.sh deploy

# Or test production config locally with Minikube
./deploy-prod.sh local

# Check status
./deploy-prod.sh status

# View logs
./deploy-prod.sh logs

# Tear down
./deploy-prod.sh delete
```

## Features

- **High Availability**: 2+ replicas with pod anti-affinity
- **Auto-scaling**: HPA scales 2-10 pods based on CPU/memory
- **Security**: Non-root containers, read-only filesystem, NetworkPolicies
- **Dynamic Storage**: Uses cluster default StorageClass
- **Ingress**: Single entry point for API
- **PodDisruptionBudget**: Safe node maintenance

## Production Files

| File | Purpose |
|------|---------|
| `k8s-prod/namespace.yaml` | Dedicated `geospatial` namespace |
| `k8s-prod/configmap.yaml` | Environment configuration |
| `k8s-prod/pvc.yaml` | Dynamic storage provisioning |
| `k8s-prod/backend-deployment.yaml` | Backend: Flask + OSRM sidecar (2 replicas) |
| `k8s-prod/services.yaml` | ClusterIP service |
| `k8s-prod/ingress.yaml` | Ingress for external access |
| `k8s-prod/pdb.yaml` | PodDisruptionBudget |
| `k8s-prod/networkpolicy.yaml` | Network isolation |
| `k8s-prod/hpa.yaml` | HorizontalPodAutoscaler |
| `k8s-prod/kustomization.yaml` | Kustomize deployment |

## Cloud Provider Configuration

### AWS EKS
```yaml
# In pvc.yaml
storageClassName: gp3

# In ingress.yaml - uncomment:
kubernetes.io/ingress.class: alb
alb.ingress.kubernetes.io/scheme: internet-facing
```

### GCP GKE
```yaml
# In pvc.yaml
storageClassName: premium-rwo

# In ingress.yaml - uncomment:
kubernetes.io/ingress.class: gce
```

### Azure AKS
```yaml
# In pvc.yaml
storageClassName: managed-premium
# NGINX Ingress recommended
```

---

# Comparison

| Feature | Local (`backend/k8s/`) | Production (`k8s-prod/`) |
|---------|------------------------|--------------------------|
| Replicas | 1 | 2+ with anti-affinity |
| Storage | hostPath | Dynamic provisioning |
| Service | NodePort | ClusterIP + Ingress |
| Auto-scaling | No | HPA (2-10 pods) |
| Network Policy | No | Yes |
| Security Context | Basic | Non-root, read-only FS |
| Image Tags | `latest` | Pinned versions |

---

# Troubleshooting

## Pods not starting
```bash
kubectl describe pod -n geospatial -l app.kubernetes.io/name=geospatial
kubectl logs -n geospatial -l app.kubernetes.io/component=backend -c osrm
kubectl logs -n geospatial -l app.kubernetes.io/component=backend -c flask
```

## OSRM data not found
- Ensure `.osrm` files are in the PersistentVolume
- For Minikube: `minikube ssh "ls -lh /mnt/geospatial-data"`

## Cannot access service
```bash
kubectl get svc -n geospatial
kubectl get ingress -n geospatial
kubectl port-forward -n geospatial svc/backend 8080:80
```
