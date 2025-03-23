#!/bin/bash
set -e
# Load configuration
CONFIG_FILE="config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file $CONFIG_FILE not found!"
  echo "Please copy config.template.sh to config.sh and update with your settings."
  exit 1
fi
source "$CONFIG_FILE"

# Determine the workspace name
WORKSPACE_NAME="$DEPLOYMENT_ID"

# Try to load state, but fall back to config if state file not found
STATE_FILE="${DEPLOYMENT_ID}_state.sh"
if [ -f "$STATE_FILE" ]; then
  echo "Loading state from $STATE_FILE"
  source "$STATE_FILE"
else
  echo "State file $STATE_FILE not found. Using values from config.sh instead."
  
  # Determine endpoint access type from CONFIG_FILE
  if [ -z "$ENDPOINT_ACCESS_TYPE" ]; then
    if [ -n "$VPC_NETWORK_NAME" ] && [ -n "$PEERING_RANGE_NAME" ]; then
      echo "Inferring VPC peering mode from configuration"
      ENDPOINT_ACCESS_TYPE="vpc_peering"
    elif [ -n "$PSC_ADDRESS_NAME" ] || [ -n "$SERVICE_ATTACHMENT" ]; then
      echo "Inferring Private Service Connect mode from configuration"
      ENDPOINT_ACCESS_TYPE="private_service_connect"
    else
      echo "Unable to determine endpoint access type, assuming public"
      ENDPOINT_ACCESS_TYPE="public"
    fi
  fi
  
  # Set deployed cluster name if not available
  if [ -z "$DEPLOYED_CLUSTER_NAME" ]; then
    DEPLOYED_CLUSTER_NAME="${WORKSPACE_NAME}-ltf-autopilot-cluster"
    echo "Setting inferred cluster name: $DEPLOYED_CLUSTER_NAME"
  fi
fi

# Terraform cleanup
echo "Destroying Terraform resources..."
cd terraform

# Select the workspace
if terraform workspace list | grep -q "$WORKSPACE_NAME"; then
    terraform workspace select "$WORKSPACE_NAME"
else
  echo "Workspace $WORKSPACE_NAME does not exist, skipping terraform destroy"
  exit 0
fi

# Configure kubectl if we have a cluster name
if [[ -n "$DEPLOYED_CLUSTER_NAME" ]]; then
  echo "Configuring kubectl..."
  gcloud container clusters get-credentials $DEPLOYED_CLUSTER_NAME --project=${PROJECT_ID} --location=${REGION} || echo "Warning: Unable to get GKE credentials, cluster may not exist"
else
  echo "Warning: Unable to get GKE cluster name, skipping kubectl configuration"
fi

# VPC Peering specific handling for Kubernetes connectivity
if [[ "${ENDPOINT_ACCESS_TYPE}" == "vpc_peering" ]]; then

  terraform state rm 'module.gke_autopilot.kubernetes_namespace.locust_namespace'
  terraform state rm 'module.gke_autopilot.kubernetes_service_account.locust_service_account' || true
  terraform state rm 'module.gke_autopilot.kubernetes_config_map.locust_config' || true
  terraform state rm 'module.gke_autopilot.kubernetes_deployment.locust_master' || true
  terraform state rm 'module.gke_autopilot.kubernetes_deployment.locust_worker' || true
  terraform state rm 'module.gke_autopilot.kubernetes_service.locust_master' || true
  terraform state rm 'module.gke_autopilot.kubernetes_service.locust_master_web' || true
  terraform state rm 'module.gke_autopilot.kubernetes_horizontal_pod_autoscaler.locust_worker_autoscaler' || true
fi

#Standard destroy
terraform destroy --auto-approve

# Delete the workspace
terraform workspace select default
terraform workspace delete --force "$WORKSPACE_NAME"
cd ..

# Deleting Locust config
rm -rf config

# Deleting Deployment state file if it exists
if [ -f "$STATE_FILE" ]; then
  rm -f "$STATE_FILE"
fi

# Artifact Registry Cleanup
if [[ -n "${DOCKER_IMAGE}" ]]; then
  echo "Cleaning up Artifact Registry repository..."
  gcloud artifacts repositories delete locust-docker-repo --location="$REGION" --project="$PROJECT_ID" --quiet --async || echo "Failed to delete Artifact Registry repository, it may not exist"
fi

echo "Cleanup complete."