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

# Load state
STATE_FILE="${DEPLOYMENT_ID}_state.sh"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file $STATE_FILE not found!"
  exit 1
fi
source "$STATE_FILE"

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
  gcloud container clusters get-credentials $DEPLOYED_CLUSTER_NAME --project=${PROJECT_ID} --location=${REGION}
else
  echo "Warning: Unable to get GKE cluster name, skipping kubectl configuration"
fi

# Destroy Terraform resources
terraform destroy --auto-approve

# Delete the workspace
terraform workspace select default
terraform workspace delete --force "$WORKSPACE_NAME"

cd ..

# Deleting Locust config
rm -rf config

# Deleting Deployment state file
rm -rf "$STATE_FILE"

# Artifact Registry Cleanup
echo "Cleaning up Artifact Registry repository..."
gcloud artifacts repositories delete locust-docker-repo-${DEPLOYMENT_ID} --location="$REGION" --project="$PROJECT_ID" --quiet --async

echo "Cleanup complete."
