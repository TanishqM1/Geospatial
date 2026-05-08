#!/bin/bash
set -euo pipefail

#######################################################################
# Geospatial Production Kubernetes Deployment Script
#
# Deploys the backend API (Flask + OSRM) to Kubernetes
#
# Usage:
#   ./deploy-prod.sh [command]
#
# Commands:
#   deploy     - Deploy all resources (default)
#   delete     - Delete all resources
#   status     - Show deployment status
#   logs       - Tail logs from backend pods
#   local      - Deploy for local development (Minikube/Docker Desktop)
#   build      - Build Docker images only
#######################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/k8s-prod"
BACKEND_DIR="${SCRIPT_DIR}/backend"
NAMESPACE="geospatial"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi

    log_info "Prerequisites OK"
}

build_images() {
    log_step "Building Docker images..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker first."
        exit 1
    fi

    # Build Flask backend image
    log_info "Building Flask backend image..."
    docker build -t geospatial-flask:v1.0.0 -f "${BACKEND_DIR}/Dockerfile.flask" "${BACKEND_DIR}"

    log_info "Docker images built successfully"
}

deploy() {
    check_prerequisites

    log_step "Deploying Geospatial Backend to Kubernetes..."

    # Apply using kustomize
    kubectl apply -k "${K8S_DIR}"

    log_info "Waiting for backend deployment to be ready..."
    kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=300s

    log_info "Deployment complete!"
    show_status
}

deploy_local() {
    check_prerequisites
    build_images

    log_step "Deploying for local development..."

    # Check if running on Minikube
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        log_info "Detected Minikube - loading images into Minikube..."
        minikube image load geospatial-flask:v1.0.0

        # Enable ingress addon if not already enabled
        if ! minikube addons list | grep -q "ingress.*enabled"; then
            log_info "Enabling Minikube ingress addon..."
            minikube addons enable ingress
        fi
    fi

    # Apply manifests
    kubectl apply -k "${K8S_DIR}"

    log_info "Waiting for backend deployment to be ready..."
    kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=300s

    log_info "Local deployment complete!"
    show_status

    # Show how to access locally
    echo ""
    log_info "To access the backend API locally:"
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        echo "  # Add to /etc/hosts: \$(minikube ip) api.geospatial.local"
        echo "  # Then access http://api.geospatial.local"
        echo ""
        echo "  # Or use port-forward:"
        echo "  kubectl port-forward -n ${NAMESPACE} svc/backend 8080:80"
    else
        echo "  kubectl port-forward -n ${NAMESPACE} svc/backend 8080:80"
        echo "  # Then access http://localhost:8080"
    fi
}

delete() {
    log_step "Deleting Geospatial from Kubernetes..."

    kubectl delete -k "${K8S_DIR}" --ignore-not-found

    log_info "Cleanup complete"
}

show_status() {
    echo ""
    log_step "=== Deployment Status ==="
    echo ""

    echo "Namespace:"
    kubectl get namespace "${NAMESPACE}" 2>/dev/null || echo "  Not found"
    echo ""

    echo "Pods:"
    kubectl get pods -n "${NAMESPACE}" -o wide 2>/dev/null || echo "  None"
    echo ""

    echo "Services:"
    kubectl get svc -n "${NAMESPACE}" 2>/dev/null || echo "  None"
    echo ""

    echo "Ingress:"
    kubectl get ingress -n "${NAMESPACE}" 2>/dev/null || echo "  None"
    echo ""

    echo "HPA:"
    kubectl get hpa -n "${NAMESPACE}" 2>/dev/null || echo "  None"
}

show_logs() {
    log_info "Tailing backend logs..."
    kubectl logs -n "${NAMESPACE}" -l app.kubernetes.io/component=backend --all-containers -f
}

# Main
case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    delete|remove|cleanup)
        delete
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    local)
        deploy_local
        ;;
    build)
        build_images
        ;;
    *)
        echo "Usage: $0 {deploy|delete|status|logs|local|build}"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy to production cluster (default)"
        echo "  delete   - Delete all resources"
        echo "  status   - Show deployment status"
        echo "  logs     - Tail backend logs"
        echo "  local    - Build images and deploy locally (Minikube)"
        echo "  build    - Build Docker images only"
        exit 1
        ;;
esac
