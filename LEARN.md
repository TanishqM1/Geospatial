# High-Level Overview: Geospatial Routing Microservice

## The Big Picture

You have a **routing microservice** that calculates distances and travel times between geographic coordinates using real road network data from British Columbia. This service runs in **Kubernetes** and consists of two separate programs that work together.

---

## 🔧 Technology Stack & Roles

### Docker - The Container Builder
**What it does:** Packages applications and their dependencies into isolated, portable containers.

**Role in this project:**
- Takes `Dockerfile.flask` and creates a **Flask container image** (like a snapshot)
- Pulls the **OSRM container image** from Docker Hub
- These images are like "executable packages" that can run anywhere

**Think of it as:** A factory that builds self-contained boxes with everything an app needs to run.

---

### Kubernetes (k8s) - The Orchestrator
**What it does:** Manages and runs containers in production, handles networking, storage, scaling, and recovery.

**Role in this project:**
- Creates a **Pod** (a group of containers that share networking)
- Runs the OSRM and Flask containers inside that Pod
- Provides shared storage (PersistentVolume) for the `.osrm` map data
- Exposes the Flask service to the outside world via a Service
- Automatically restarts containers if they crash
- Handles networking so containers can talk to each other

**Think of it as:** A smart manager that keeps your containers running, connected, and healthy.

---

### Minikube - The Local Kubernetes Cluster
**What it does:** Runs a single-node Kubernetes cluster on your local machine for development/testing.

**Role in this project:**
- Creates a mini Kubernetes environment on your Windows PC
- Uses Docker Desktop as the "driver" to run the cluster
- Provides a local testing environment that mimics production Kubernetes (like AKS, EKS, GKE)
- Manages the `/mnt/geospatial-data` storage inside the cluster

**Think of it as:** A local playground that simulates a real cloud Kubernetes environment.

---

## 📁 File Explanations

### YAML Files (Kubernetes Configuration)

#### `k8s/pv-pvc.yaml` - Storage Setup
```yaml
PersistentVolume (PV)       → Creates storage space at /mnt/geospatial-data
PersistentVolumeClaim (PVC) → Requests access to that storage
```
**Purpose:** Stores your preprocessed OSRM map data (`.osrm` files) so both containers can read it.

#### `k8s/deployment.yaml` - The Application Definition
```yaml
Deployment:
  Pod:
    Container 1 (osrm):
      - Image: osrm/osrm-backend:latest
      - Command: osrm-routed --algorithm mld /data/british-columbia-251029.osrm
      - Port: 5000
      - Volume: /data (shared with Flask)
      
    Container 2 (flask):
      - Image: geospatial-flask:latest
      - Environment: OSRM_URL=http://127.0.0.1:5000
      - Port: 8080
      - Volume: /data (shared with OSRM)
```
**Purpose:** Defines how to run both containers together in one Pod with shared networking and storage.

**Key concept:** Both containers are in the **same Pod**, so they share:
- Network namespace (can use `localhost` to talk)
- Storage volumes (both see `/data`)

#### `k8s/service.yaml` - External Access
```yaml
Service (NodePort):
  - Exposes port 80
  - Routes to Flask container port 8080
  - Makes the service accessible from outside the cluster
```
**Purpose:** Creates a network endpoint so external requests can reach the Flask API.

---

### PowerShell Script

#### `setup-k8s.ps1` - Automated Deployment Script
**What it does (step-by-step):**

1. **Checks prerequisites** - Verifies minikube, kubectl, docker are installed
2. **Starts minikube** - Launches local Kubernetes cluster
3. **Copies OSRM data** - Transfers `.osrm` files into minikube VM at `/mnt/geospatial-data`
4. **Configures Docker** - Points Docker CLI to minikube's Docker daemon
5. **Builds Flask image** - Creates `geospatial-flask:latest` container image
6. **Pulls OSRM image** - Downloads official OSRM backend image
7. **Applies manifests** - Creates PV, PVC, Deployment, Service in Kubernetes
8. **Waits for readiness** - Ensures pods are running before finishing

**Purpose:** Automates the entire setup process so you can deploy with one command.

---

## 🏃 How Flask and OSRM Run

### Architecture Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (Minikube)            │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                  Pod: geospatial                     │  │
│   │                                                      │  │
│   │  ┌──────────────────────────────────────────────┐   │  │
│   │  │     Shared Network Namespace (localhost)     │   │  │
│   │  │                                              │   │  │
│   │  │   ┌────────────────┐  ┌──────────────────┐  │   │  │
│   │  │   │ OSRM Container │  │  Flask Container │  │   │  │
│   │  │   │                │  │                  │  │   │  │
│   │  │   │ Port: 5000     │◄─┤ Calls:          │  │   │  │
│   │  │   │ Listens on     │  │ localhost:5000  │  │   │  │
│   │  │   │ 0.0.0.0:5000   │  │                  │  │   │  │
│   │  │   │                │  │ Port: 8080       │  │   │  │
│   │  │   │ Reads map data │  │ Exposes API      │  │   │  │
│   │  │   └────────┬───────┘  └────────┬─────────┘  │   │  │
│   │  └────────────┼──────────────────┼─────────────┘   │  │
│   │               │                  │                  │  │
│   │               ▼                  ▼                  │  │
│   │         ┌─────────────────────────────┐            │  │
│   │         │  PersistentVolume           │            │  │
│   │         │  /data/                     │            │  │
│   │         │  ├─ british-columbia.osrm   │            │  │
│   │         │  ├─ *.osrm.mldgr            │            │  │
│   │         │  ├─ *.osrm.partition        │            │  │
│   │         │  └─ ... (30+ files)         │            │  │
│   │         └─────────────────────────────┘            │  │
│   └──────────────────────────────────────────────────────┘  │
│                             │                               │
│                             ▼                               │
│                    ┌─────────────────┐                      │
│                    │ Service         │                      │
│                    │ NodePort: 80    │                      │
│                    └────────┬────────┘                      │
└─────────────────────────────┼───────────────────────────────┘
                              │
                              ▼
                    kubectl port-forward
                              │
                              ▼
                    http://localhost:8080
                              │
                              ▼
                     Your Python test script
```

### Communication Flow

**Step-by-step request flow:**

1. **External Request**
   ```
   test_matrix.py sends POST to http://localhost:8080/matrix
   ```

2. **Port Forward** (kubectl tool running in background)
   ```
   localhost:8080 → Kubernetes Service → Flask container port 8080
   ```

3. **Flask Receives Request**
   ```python
   Flask receives: {"coordinates": [[-123.3656, 48.4284], ...]}
   Reads OSRM_URL from environment: http://127.0.0.1:5000
   ```

4. **Flask → OSRM** (Internal communication via localhost)
   ```
   Flask makes HTTP request to: http://127.0.0.1:5000/table/v1/driving/...
   This stays INSIDE the Pod - never leaves the container
   ```

5. **OSRM Processes Request**
   ```
   OSRM reads map data from /data/british-columbia-251029.osrm
   Calculates shortest paths using MLD algorithm
   Returns JSON with distances and durations
   ```

6. **Response Path**
   ```
   OSRM → Flask (localhost) → Service → port-forward → test_matrix.py
   ```

### Why Localhost Works

**Critical concept:** In Kubernetes, all containers in the same Pod share:
- **Network namespace** - They see the same network interfaces
- **Loopback interface** - `localhost`/`127.0.0.1` refers to the Pod, not the individual container

This means:
- Flask calling `http://127.0.0.1:5000` reaches OSRM
- It's as if both programs are running on the same computer
- No network routing needed - ultra-fast communication

---

## 🌐 Where They Run in Production

### Current Setup (Development)
- **Where:** Local Windows PC
- **Environment:** Minikube (single-node Kubernetes cluster)
- **Access:** `kubectl port-forward` on localhost

### Real Production (Cloud)
If you deployed to a cloud Kubernetes service:

#### Option 1: Keep Sidecar Pattern (Recommended for tight coupling)
```
Cloud Kubernetes (AKS/EKS/GKE)
├── Pod (multiple replicas for high availability)
│   ├── OSRM container (port 5000)
│   └── Flask container (port 8080, calls localhost:5000)
├── LoadBalancer Service (public IP)
└── PersistentVolume (cloud storage: Azure Files, EBS, GCS)
```
**Benefits:**
- Simple networking (localhost)
- Atomic scaling (both containers scale together)
- Shared data access

#### Option 2: Separate Deployments (For independent scaling)
```
Cloud Kubernetes
├── OSRM Deployment
│   ├── OSRM Pods (3 replicas)
│   └── ClusterIP Service: osrm:5000
├── Flask Deployment
│   ├── Flask Pods (10 replicas, scaled independently)
│   └── Flask calls: http://osrm:5000 (DNS name)
├── LoadBalancer Service (exposes Flask)
└── Separate PersistentVolumes
```
**Benefits:**
- Scale Flask and OSRM independently
- Better resource utilization
- Easier to update one without affecting the other

**Environment variable changes:**
- Sidecar: `OSRM_URL=http://127.0.0.1:5000`
- Separate: `OSRM_URL=http://osrm:5000` (Kubernetes DNS)

---

## 🍎 Running on Mac

### Prerequisites
```bash
# Install Homebrew (if not already)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install tools
brew install kubectl
brew install minikube
brew install docker  # Or install Docker Desktop app
```

### Modified Setup Script (Mac)
Create `setup-k8s.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=================================="
echo "  Geospatial K8s Setup (Mac)"
echo "=================================="

# Start minikube
echo -e "\n[1/7] Starting minikube..."
minikube start --driver=docker --cpus=2 --memory=6144

# Copy OSRM data
echo -e "\n[2/7] Copying OSRM data..."
minikube ssh "sudo mkdir -p /mnt/geospatial-data"
for file in data/british-columbia-251029.osrm*; do
    echo "  Copying $(basename $file)..."
    minikube cp "$file" "/mnt/geospatial-data/$(basename $file)"
done

# Configure Docker environment
echo -e "\n[3/7] Configuring Docker..."
eval $(minikube docker-env)

# Build Flask image
echo -e "\n[4/7] Building Flask image..."
docker build -f Dockerfile.flask -t geospatial-flask:latest .

# Pull OSRM image
echo -e "\n[5/7] Pulling OSRM image..."
docker pull osrm/osrm-backend:latest

# Deploy to Kubernetes
echo -e "\n[6/7] Deploying to Kubernetes..."
kubectl apply -f k8s/pv-pvc.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Wait for pods
echo -e "\n[7/7] Waiting for pods..."
kubectl wait --for=condition=ready pod -l app=geospatial --timeout=120s

# Show status
echo -e "\n=================================="
echo "  Deployment Complete!"
echo "=================================="
kubectl get pods -l app=geospatial
kubectl get svc geospatial

echo -e "\nStart port-forward in another terminal:"
echo "  kubectl port-forward svc/geospatial 8080:80"
echo -e "\nThen test with:"
echo "  python test_matrix.py"
```

### Make it executable and run
```bash
chmod +x setup-k8s.sh
./setup-k8s.sh
```

### Daily usage on Mac
```bash
# Start (if stopped)
minikube start

# Port forward (keep terminal open)
kubectl port-forward svc/geospatial 8080:80

# Test (in another terminal)
python test_matrix.py

# View logs
kubectl logs -l app=geospatial -c osrm -f
kubectl logs -l app=geospatial -c flask -f

# Stop
minikube stop
```

### Key Differences: Mac vs Windows
| Aspect | Windows | Mac |
|--------|---------|-----|
| Script extension | `.ps1` | `.sh` |
| Shell | PowerShell | Bash |
| Minikube path | `$env:USERPROFILE\bin\minikube.exe` | `minikube` (in PATH) |
| Docker env | `Invoke-Expression` | `eval $(...)` |
| Everything else | **Identical** | **Identical** |

The YAML files, Docker images, and Kubernetes concepts are exactly the same!

---

## 🎓 Key Concepts Summary

### 1. Containers vs Pods vs Deployments
- **Container** = One running instance of an application (OSRM or Flask)
- **Pod** = Group of containers that share networking and storage (our OSRM + Flask pair)
- **Deployment** = Kubernetes management object that ensures Pods stay running

### 2. Networking Layers
```
External Request
    ↓
Service (load balancer / routing)
    ↓
Pod Network (Kubernetes manages)
    ↓
Container Network Namespace (shared in Pod)
    ↓
localhost (127.0.0.1 - same Pod)
```

### 3. Storage Layers
```
Physical Disk
    ↓
Host Path (/mnt/geospatial-data on minikube VM)
    ↓
PersistentVolume (Kubernetes abstraction)
    ↓
PersistentVolumeClaim (Pod's request)
    ↓
Volume Mount (/data inside containers)
```

### 4. Why This Architecture?
**Sidecar Pattern Benefits:**
- ✅ Fast communication (localhost, no network overhead)
- ✅ Shared data access (both read same files)
- ✅ Simple networking (no DNS, no service discovery)
- ✅ Atomic deployment (both containers deployed together)
- ✅ Easier security (OSRM not exposed externally)

**Trade-offs:**
- ⚠️ Both scale together (can't scale Flask independently)
- ⚠️ If OSRM crashes, Flask calls fail immediately
- ⚠️ Larger Pods (more resources per Pod)

### 5. Production Readiness Checklist
To go from local development to production, you'd need:

- [ ] Replace minikube with cloud Kubernetes (AKS/EKS/GKE)
- [ ] Use cloud storage (Azure Files, EBS, GCS) instead of hostPath
- [ ] Add Ingress controller + TLS certificates
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure horizontal pod autoscaling (HPA)
- [ ] Add resource requests/limits tuning
- [ ] Set up CI/CD pipeline (GitHub Actions, GitLab CI)
- [ ] Add logging aggregation (Fluentd, Elasticsearch)
- [ ] Implement health checks and readiness probes (already done!)
- [ ] Set up secrets management (for any credentials)

---

## 🔍 Troubleshooting Guide

### "Pod not starting"
```bash
# Check what's wrong
kubectl describe pod -l app=geospatial

# Common issues:
# - Image not found: Re-run docker build
# - Data not found: Check minikube cp worked
# - Resource limits: Increase minikube memory
```

### "Cannot connect to localhost:8080"
```bash
# Ensure port-forward is running
kubectl port-forward svc/geospatial 8080:80

# Keep that terminal open!
```

### "OSRM data not found"
```bash
# Verify data was copied
minikube ssh "ls -lh /mnt/geospatial-data"

# Should see 30+ .osrm files
```

### "Containers can't communicate"
```bash
# Check both containers are in same Pod
kubectl get pods -l app=geospatial -o wide

# Should show 2/2 READY (both containers running)

# Test from inside Pod
kubectl exec -it <pod-name> -c flask -- curl http://127.0.0.1:5000/
```

---

## 📚 Further Learning

### To understand Kubernetes better:
1. **Official Tutorial:** https://kubernetes.io/docs/tutorials/
2. **Pod Networking:** https://kubernetes.io/docs/concepts/workloads/pods/#pod-networking
3. **Sidecar Pattern:** https://kubernetes.io/docs/concepts/workloads/pods/#workload-resources-for-managing-pods

### To understand Docker:
1. **Docker Tutorial:** https://docs.docker.com/get-started/
2. **Multi-stage Builds:** https://docs.docker.com/build/building/multi-stage/

### To understand OSRM:
1. **OSRM Documentation:** http://project-osrm.org/
2. **MLD Algorithm:** https://github.com/Project-OSRM/osrm-backend/wiki/Multi-Level-Dijkstra

---

## 🎉 You're Done!

You now have a fully functional, production-like routing microservice running on Kubernetes. The concepts you've learned here apply directly to real cloud deployments - the only differences are scale and infrastructure details.

**What you've built:**
- ✅ Containerized applications
- ✅ Multi-container Pods
- ✅ Kubernetes orchestration
- ✅ Persistent storage
- ✅ Service networking
- ✅ Localhost inter-container communication
- ✅ Development workflow automation

**Next steps:**
1. Try modifying `app.py` to add new endpoints
2. Experiment with multiple replicas: `kubectl scale deployment geospatial --replicas=3`
3. Try the separate Deployments architecture
4. Deploy to a real cloud provider (AWS EKS, Azure AKS, Google GKE)

Happy routing! 🚗🗺️
