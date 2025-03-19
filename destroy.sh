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

# Destroy Terraform resources
terraform destroy --auto-approve

# Delete the workspace
terraform workspace select default
terraform workspace delete --force "$WORKSPACE_NAME"

cd ..

# Deleting Locust config
rm -rf config

# Artifact Registry Cleanup
echo "Cleaning up Artifact Registry repository..."
gcloud artifacts repositories delete locust-docker-repo-${DEPLOYMENT_ID} --location="$REGION" --project="$PROJECT_ID" --quiet --async



# Commented out the below code becaues they might be using some of the services before using load testing framework.
# Disable any enabled services
# echo "Disabling services..."
# gcloud services disable aiplatform.googleapis.com \
#   artifactregistry.googleapis.com \
#   compute.googleapis.com \
#   autoscaling.googleapis.com \
#   container.googleapis.com \
#   iamcredentials.googleapis.com \
#   cloudbuild.googleapis.com \
#   iam.googleapis.com \
#   servicenetworking.googleapis.com \
#   --project="${PROJECT_ID}" --quiet

echo "Cleanup complete."
