# Infrastructure Documentation

## This is an overview of the infrastructure structure of this project.

## Components

### 1. Multi Node Kubernetes Cluster
- The infrastructure is designed to run on a multi-node Kubernetes cluster: 1 manager and 2 workers.

### 2. Script for using the application in the local environment
- The script `kubectl-port-forwarding.sh` is used to set up port forwarding for the services running in the Kubernetes cluster. It allows you to access the services from your local machine.

#### Services port forwarding
```bash
# Port forwarding for Grafana
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus-stack" -o name)
kubectl --namespace monitoring port-forward $POD_NAME 3000 

# Run the port-forwarding script for api gateway, portainer, and mongo express
bash kubectl-port-forwarding.sh
```