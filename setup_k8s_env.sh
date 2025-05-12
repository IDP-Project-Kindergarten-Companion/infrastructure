#!/bin/bash

# Script to set up the local Kubernetes development environment
# for the Kindergarten Companion project.

# Prerequisites:
# 1. Docker installed and running.
# 2. A local Kubernetes cluster enabled and running (e.g., Docker Desktop Kubernetes, Minikube, Kind).
# 3. kubectl installed and configured to point to your local cluster.
# 4. The 'deployment' repository cloned, ideally as a sibling to this 'infrastructure' repo.
#    If not, adjust DEPLOYMENT_REPO_PATH.

# --- Configuration ---
# Adjust this path if your 'deployment' repository is located elsewhere relative to this script.
DEPLOYMENT_REPO_PATH="../deployment" # Assumes 'deployment' and 'infrastructure' are sibling dirs
K8S_NAMESPACE="kindergarten-app"

# --- Helper Functions ---
print_header() {
  echo ""
  echo "================================================================================"
  echo ">>> $1"
  echo "================================================================================"
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: $1 is not installed or not in your PATH. Please install it and try again."
    exit 1
  fi
}

# --- Sanity Checks ---
print_header "Running Sanity Checks"
check_command "kubectl"
check_command "docker"

echo "Checking kubectl context..."
kubectl config current-context
kubectl cluster-info
echo "If the above does not point to your local cluster, please configure kubectl."
print_separator

# --- Step 1: Ensure Namespace ---
print_header "Step 1: Applying Namespace"
if [ -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/kindergarten-namespace.yaml" ]; then
  kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/kindergarten-namespace.yaml"
else
  echo "Warning: Namespace file not found at ${DEPLOYMENT_REPO_PATH}/k8s/core-services/kindergarten-namespace.yaml"
  echo "Attempting to create namespace '${K8S_NAMESPACE}' directly..."
  kubectl create namespace "${K8S_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
fi
print_separator

# --- Step 2: Handle Secrets ---
print_header "Step 2: Handling Secrets"
APP_SECRETS_EXAMPLE_PATH="${DEPLOYMENT_REPO_PATH}/k8s/core-services/app-secrets.example.yaml"
APP_SECRETS_PATH="${DEPLOYMENT_REPO_PATH}/k8s/core-services/app-secrets.yaml" # This is the one that should contain real values

if [ ! -f "${APP_SECRETS_PATH}" ]; then
  echo "Warning: Actual 'app-secrets.yaml' not found at ${APP_SECRETS_PATH}."
  if [ -f "${APP_SECRETS_EXAMPLE_PATH}" ]; then
    echo "An example secrets file exists at: ${APP_SECRETS_EXAMPLE_PATH}"
    echo "Please COPY this example to 'app-secrets.yaml' in the same directory,"
    echo "fill it with your actual secret values, and then re-run this script."
    echo "For now, attempting to apply the example (this will likely cause issues for services)."
    kubectl apply -f "${APP_SECRETS_EXAMPLE_PATH}" -n "${K8S_NAMESPACE}"
  else
    echo "Error: Neither 'app-secrets.yaml' nor 'app-secrets.example.yaml' found."
    echo "Please create 'app-secrets.yaml' with the necessary secrets in ${DEPLOYMENT_REPO_PATH}/k8s/core-services/."
    exit 1
  fi
else
  echo "Applying secrets from ${APP_SECRETS_PATH}..."
  kubectl apply -f "${APP_SECRETS_PATH}" -n "${K8S_NAMESPACE}"
fi
print_separator

# --- Step 3: Deploy Databases ---
print_header "Step 3: Deploying Databases (MongoDB instances)"
echo "Deploying Auth MongoDB..."
kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/auth/auth-mongo.yaml" -n "${K8S_NAMESPACE}"
echo "Deploying Operational MongoDB..."
kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/db-interact/operational-mongo.yaml" -n "${K8S_NAMESPACE}" 
# Note: Your file was named operational-mogo.yaml, I assumed it's operational-mongo.yaml. Please verify.
print_separator

# --- Step 4: Deploy Core Application Services ---
print_header "Step 4: Deploying Core Application Services"
echo "Deploying Auth Service..."
kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/auth/auth-service-k8s.yaml" -n "${K8S_NAMESPACE}"

echo "Deploying DB-Interact Service..."
kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/db-interact/db-interact-k8s.yaml" -n "${K8S_NAMESPACE}"

echo "Deploying Child-Profile Service..."
kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/child-profile/child-profile-deployment.yaml" -n "${K8S_NAMESPACE}"
kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/child-profile/child-profile-svc.yaml" -n "${K8S_NAMESPACE}"


echo "Deploying Activity-Log Service..."
kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/activity-log/activity-log-deployment.yaml" -n "${K8S_NAMESPACE}"
kubectl apply -f "${DEPLOYMENT_REPO_PATH}/k8s/core-services/activity-log/activity-log-svc.yaml" -n "${K8S_NAMESPACE}"

print_separator

# --- Step 5: Wait for Deployments and Provide Status ---
print_header "Step 5: Checking Deployment Status (may take a few minutes for images to pull and pods to start)"
echo "Waiting for Auth MongoDB to be ready..."
kubectl rollout status statefulset/auth-mongo -n "${K8S_NAMESPACE}" --timeout=5m
echo "Waiting for Operational MongoDB to be ready..."
kubectl rollout status statefulset/operational-mongo -n "${K8S_NAMESPACE}" --timeout=5m

echo "Waiting for Auth Service deployment..."
kubectl rollout status deployment/auth-service-deployment -n "${K8S_NAMESPACE}" --timeout=5m
echo "Waiting for DB-Interact Service deployment..."
kubectl rollout status deployment/db-interact-deployment -n "${K8S_NAMESPACE}" --timeout=5m
echo "Waiting for Child-Profile Service deployment..."
kubectl rollout status deployment/child-profile-deployment -n "${K8S_NAMESPACE}" --timeout=5m
echo "Waiting for Activity-Log Service deployment..."
kubectl rollout status deployment/activity-log-deployment -n "${K8S_NAMESPACE}" --timeout=5m

print_header "Current Pod Status"
kubectl get pods -n "${K8S_NAMESPACE}" -o wide

print_header "Current Service Status"
kubectl get svc -n "${K8S_NAMESPACE}"

print_separator
echo "Setup script complete."
echo "If any deployments are not ready, check their logs using 'kubectl logs <pod-name> -n ${K8S_NAMESPACE}'."
echo "To access services locally, you'll need to use 'kubectl port-forward':"
echo "  auth-service: kubectl port-forward svc/auth-svc -n ${K8S_NAMESPACE} 8081:5051"
echo "  db-interact-service: kubectl port-forward svc/db-interact-svc -n ${K8S_NAMESPACE} 8082:5000"
echo "  child-profile-service: kubectl port-forward svc/child-profile-svc -n ${K8S_NAMESPACE} 8083:5002"
echo "  activity-log-service: kubectl port-forward svc/activity-log-svc -n ${K8S_NAMESPACE} 8084:5003"
echo ""
echo "Remember: If your CI/CD has pushed new images to Docker Hub, run 'kubectl rollout restart deployment/<deployment-name> -n ${K8S_NAMESPACE}' for the respective service to pull the latest image."

