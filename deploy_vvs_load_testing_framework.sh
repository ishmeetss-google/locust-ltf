#!/bin/bash
set -e  # Exit on any error

# Check for configuration file
CONFIG_FILE="config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file $CONFIG_FILE not found!"
  echo "Please copy config.template.sh to config.sh and update with your settings."
  exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Generate dynamic variables
TIMESTAMP=$(date +%Y%m%d%H%M%S)
DOCKER_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/locust-docker-repo/locust-load-test:LTF-${TIMESTAMP}"
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# Print configuration for verification
echo "==================================="
echo "Configuration Summary:"
echo "==================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Zone: $ZONE"
echo "Timestamp: $TIMESTAMP"
echo "Docker Image: $DOCKER_IMAGE"
echo "Index Dimensions: $INDEX_DIMENSIONS"
echo "Project Number: $PROJECT_NUMBER"
echo "Deployment ID: $DEPLOYMENT_ID"
echo "==================================="

if [[ -n "$VECTOR_SEARCH_INDEX_ID" ]]; then
  echo "Using existing Vector Search index: $VECTOR_SEARCH_INDEX_ID"
else
  echo "Creating new Vector Search index from data in gs://$BUCKET_NAME/$EMBEDDING_PATH"
fi
echo "==================================="
echo "Continue with deployment? (y/n)"
read -r confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled."
  exit 0
fi

# Ask about external IP preference early
read -r -p "Do you need an external IP? (y/n): " need_external_ip
export need_external_ip

echo "External IP requested status =" $need_external_ip

# Enable required services
echo "Enabling required Google Cloud services..."
gcloud services enable aiplatform.googleapis.com \
  artifactregistry.googleapis.com \
  compute.googleapis.com \
  autoscaling.googleapis.com \
  container.googleapis.com \
  iamcredentials.googleapis.com \
  cloudbuild.googleapis.com \
  iam.googleapis.com \
  --project="${PROJECT_ID}"

# Create Artifact Registry repository
echo "Creating Artifact Registry repository..."
gcloud artifacts repositories create locust-docker-repo --repository-format=docker --location="${REGION}" --project="${PROJECT_ID}" || true

# Create config directory
mkdir -p config
touch config/locust_config.env
# Set correct permissions
chmod 666 ./public_http_query.py    
chmod 666 config/locust_config.env

# Phase 1: Deploy Vector Search infrastructure first
echo "Deploying Vector Search infrastructure, this can take a while..."
cd terraform

# Check if the workspace exists using `terraform workspace list | grep`
if terraform workspace list | grep -q "$DEPLOYMENT_ID"; then
  # Workspace exists, switch to it
  echo "Workspace '$DEPLOYMENT_ID' already exists. Switching to it..."
  terraform workspace select "$DEPLOYMENT_ID"
else
  # Workspace doesn't exist, create it
  echo "Workspace '$DEPLOYMENT_ID' does not exist. Creating it..."
  terraform workspace new "$DEPLOYMENT_ID"
fi

# Optional: Verify the current workspace after switching/creating
current_workspace=$(terraform workspace show)
echo "Current Terraform workspace: $current_workspace"

terraform workspace select $DEPLOYMENT_ID

# Create or update terraform.tfvars with appropriate settings
cat <<EOF > terraform.tfvars
project_id     = "${PROJECT_ID}"
region         = "${REGION}"
project_number = "${PROJECT_NUMBER}"
deployment_id  = "${DEPLOYMENT_ID}"
EOF

# Check if we're using an existing index or need to create a new one
if [[ -n "${VECTOR_SEARCH_INDEX_ID}" ]]; then
  # Using existing index
  echo "vector_search_index_id = \"${VECTOR_SEARCH_INDEX_ID}\"" >> terraform.tfvars
else
  # Using bucket and path for new index
  echo "existing_bucket_name = \"${BUCKET_NAME}\"" >> terraform.tfvars
  echo "embedding_data_path = \"${EMBEDDING_PATH}\"" >> terraform.tfvars
fi

# Add other common settings
cat <<EOF >> terraform.tfvars
index_dimensions = ${INDEX_DIMENSIONS}
deployed_index_resource_type = "${DEPLOYED_INDEX_RESOURCE_TYPE:-dedicated}"
deployed_index_dedicated_machine_type = "${DEPLOYED_INDEX_DEDICATED_MACHINE_TYPE:-e2-standard-16}"
endpoint_public_endpoint_enabled = ${ENDPOINT_PUBLIC_ENDPOINT_ENABLED:-true}
image = "${DOCKER_IMAGE}"
EOF

# Add optional settings if defined
[[ -n "$INDEX_DISPLAY_NAME" ]] && echo "index_display_name = \"$INDEX_DISPLAY_NAME\"" >> terraform.tfvars
[[ -n "$INDEX_DESCRIPTION" ]] && echo "index_description = \"$INDEX_DESCRIPTION\"" >> terraform.tfvars
[[ -n "$INDEX_LABELS" ]] && echo "index_labels = $INDEX_LABELS" >> terraform.tfvars
[[ -n "$INDEX_APPROXIMATE_NEIGHBORS_COUNT" ]] && echo "index_approximate_neighbors_count = $INDEX_APPROXIMATE_NEIGHBORS_COUNT" >> terraform.tfvars
[[ -n "$INDEX_DISTANCE_MEASURE_TYPE" ]] && echo "index_distance_measure_type = \"$INDEX_DISTANCE_MEASURE_TYPE\"" >> terraform.tfvars
[[ -n "$INDEX_SHARD_SIZE" ]] && echo "index_shard_size = \"$INDEX_SHARD_SIZE\"" >> terraform.tfvars
[[ -n "$FEATURE_NORM_TYPE" ]] && echo "feature_norm_type = \"$FEATURE_NORM_TYPE\"" >> terraform.tfvars
[[ -n "$INDEX_ALGORITHM_CONFIG_TYPE" ]] && echo "index_algorithm_config_type = \"$INDEX_ALGORITHM_CONFIG_TYPE\"" >> terraform.tfvars
[[ -n "$INDEX_TREE_AH_LEAF_NODE_EMBEDDING_COUNT" ]] && echo "index_tree_ah_leaf_node_embedding_count = $INDEX_TREE_AH_LEAF_NODE_EMBEDDING_COUNT" >> terraform.tfvars
[[ -n "$INDEX_TREE_AH_LEAF_NODES_TO_SEARCH_PERCENT" ]] && echo "index_tree_ah_leaf_nodes_to_search_percent = $INDEX_TREE_AH_LEAF_NODES_TO_SEARCH_PERCENT" >> terraform.tfvars
[[ -n "$INDEX_UPDATE_METHOD" ]] && echo "index_update_method = \"$INDEX_UPDATE_METHOD\"" >> terraform.tfvars

[[ -n "$ENDPOINT_DISPLAY_NAME" ]] && echo "endpoint_display_name = \"$ENDPOINT_DISPLAY_NAME\"" >> terraform.tfvars
[[ -n "$ENDPOINT_DESCRIPTION" ]] && echo "endpoint_description = \"$ENDPOINT_DESCRIPTION\"" >> terraform.tfvars
[[ -n "$ENDPOINT_LABELS" ]] && echo "endpoint_labels = $ENDPOINT_LABELS" >> terraform.tfvars
[[ -n "$ENDPOINT_NETWORK" ]] && echo "endpoint_network = \"$ENDPOINT_NETWORK\"" >> terraform.tfvars
[[ -n "$ENDPOINT_ENABLE_PRIVATE_SERVICE_CONNECT" ]] && echo "endpoint_enable_private_service_connect = $ENDPOINT_ENABLE_PRIVATE_SERVICE_CONNECT" >> terraform.tfvars
[[ -n "$ENDPOINT_CREATE_TIMEOUT" ]] && echo "endpoint_create_timeout = \"$ENDPOINT_CREATE_TIMEOUT\"" >> terraform.tfvars
[[ -n "$ENDPOINT_UPDATE_TIMEOUT" ]] && echo "endpoint_update_timeout = \"$ENDPOINT_UPDATE_TIMEOUT\"" >> terraform.tfvars
[[ -n "$ENDPOINT_DELETE_TIMEOUT" ]] && echo "endpoint_delete_timeout = \"$ENDPOINT_DELETE_TIMEOUT\"" >> terraform.tfvars

[[ -n "$DEPLOYED_INDEX_ID" ]] && echo "deployed_index_id = \"$DEPLOYED_INDEX_ID\"" >> terraform.tfvars
[[ -n "$DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS" ]] && echo "deployed_index_dedicated_min_replicas = $DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS" >> terraform.tfvars
[[ -n "$DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS" ]] && echo "deployed_index_dedicated_max_replicas = $DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS" >> terraform.tfvars
[[ -n "$DEPLOYED_INDEX_AUTOMATIC_MIN_REPLICAS" ]] && echo "deployed_index_automatic_min_replicas = $DEPLOYED_INDEX_AUTOMATIC_MIN_REPLICAS" >> terraform.tfvars
[[ -n "$DEPLOYED_INDEX_AUTOMATIC_MAX_REPLICAS" ]] && echo "deployed_index_automatic_max_replicas = $DEPLOYED_INDEX_AUTOMATIC_MAX_REPLICAS" >> terraform.tfvars
[[ -n "$DEPLOYED_INDEX_RESERVED_IP_RANGES" ]] && echo "deployed_index_reserved_ip_ranges = $DEPLOYED_INDEX_RESERVED_IP_RANGES" >> terraform.tfvars
[[ -n "$DEPLOYED_INDEX_CREATE_TIMEOUT" ]] && echo "deployed_index_create_timeout = \"$DEPLOYED_INDEX_CREATE_TIMEOUT\"" >> terraform.tfvars
[[ -n "$DEPLOYED_INDEX_UPDATE_TIMEOUT" ]] && echo "deployed_index_update_timeout = \"$DEPLOYED_INDEX_UPDATE_TIMEOUT\"" >> terraform.tfvars
[[ -n "$DEPLOYED_INDEX_DELETE_TIMEOUT" ]] && echo "deployed_index_delete_timeout = \"$DEPLOYED_INDEX_DELETE_TIMEOUT\"" >> terraform.tfvars

cat terraform.tfvars

# Initialize and apply just the vector search module
terraform init

echo "Deploying vector search in the Terraform workspace: $DEPLOYMENT_ID"
terraform apply -target=module.vector_search --auto-approve


# Extract crucial values from Terraform output
echo "Extracting Vector Search configuration..."
export VS_DIMENSIONS=${INDEX_DIMENSIONS}
export VS_DEPLOYED_INDEX_ID=$(terraform output -raw vector_search_deployed_index_endpoint_id)
export VS_INDEX_ENDPOINT_ID=$(terraform output -raw vector_search_index_endpoint_id)
export VS_ENDPOINT_HOST=$(terraform output -raw vector_search_deployed_index_endpoint_host)

# Save these to a temporary file for Docker build
cd ..
cat <<EOF > config/locust_config.env
INDEX_DIMENSIONS=${VS_DIMENSIONS}
DEPLOYED_INDEX_ID=${VS_DEPLOYED_INDEX_ID}
INDEX_ENDPOINT_ID=${VS_INDEX_ENDPOINT_ID}
ENDPOINT_HOST=${VS_ENDPOINT_HOST}
PROJECT_ID=${PROJECT_ID}
EOF

# Phase 2: Build and push Docker image with the config
echo "Building and pushing Docker image..."

# Build and push the Docker image
gcloud builds submit --project=${PROJECT_ID} --tag ${DOCKER_IMAGE}

# Phase 3: Deploy the rest of the infrastructure
echo "Deploying remaining infrastructure..."
cd terraform

terraform workspace select $DEPLOYMENT_ID

echo "Deploying in the Terraform workspace: $DEPLOYMENT_ID"

# Apply the full infrastructure
terraform apply --auto-approve


DEPLOYED_CLUSTER_SVC=$(terraform output -raw locust_master_svc_name)
DEPLOYED_CLUSTER_MAIN_NODE=$(terraform output -raw locust_master_node_name)
DEPLOYED_CLUSTER_NAME=$(terraform output -raw gke_cluster_name)
NGINX_PROXY_NAME=$(terraform output -raw nginx_proxy_name)

echo $DEPLOYED_CLUSTER_MAIN_NODE
echo $DEPLOYED_CLUSTER_SVC
echo $DEPLOYED_CLUSTER_NAME
echo $NGINX_PROXY_NAME

# Configure kubectl
echo "Configuring kubectl..."
gcloud container clusters get-credentials $DEPLOYED_CLUSTER_NAME --project=${PROJECT_ID} --location=${REGION}

echo "==================================="
echo "Deployment Complete!"
echo "==================================="

# Setup access
if [[ "${need_external_ip,,}" =~ ^(y|yes)$ ]]; then
    kubectl delete svc ${DEPLOYED_CLUSTER_SVC} 
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${DEPLOYED_CLUSTER_SVC}
spec:
  type: LoadBalancer
  ports:
  - port: 8089
    targetPort: 8089
    name: web-ui
  selector:
    app: ${DEPLOYED_CLUSTER_MAIN_NODE}
EOF
# Wait for the external IP to be assigned
echo "Waiting for external IP to be assigned..."
while true; do
  EXTERNAL_IP=$(kubectl get svc ${DEPLOYED_CLUSTER_SVC} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo "Still waiting for external IP..."
  sleep 5
done

# Display the service information
kubectl get svc ${DEPLOYED_CLUSTER_SVC}

# Print the access URL with the actual IP
echo "Access Locust UI at http://$EXTERNAL_IP:8089"
else
    echo "Access Locust UI by running:"
    echo "gcloud compute ssh ${NGINX_PROXY_NAME} --project ${PROJECT_ID} --zone ${ZONE} -- -NL 8089:localhost:8089"
    echo "Then open http://localhost:8089 in your browser"
fi

# Verify deployment
echo "Verifying deployments..."
kubectl get deployments