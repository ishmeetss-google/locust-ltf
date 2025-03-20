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
DOCKER_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/locust-docker-repo-${DEPLOYMENT_ID}/locust-load-test:LTF-${TIMESTAMP}"
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# Set test type and endpoint access based on ENDPOINT_ACCESS_TYPE
case "${ENDPOINT_ACCESS_TYPE}" in
  "public")
    export TF_VAR_endpoint_access='{"type":"public"}'
    export LOCUST_TEST_TYPE="http"
    echo "Configuring public endpoint access with HTTP tests"
    ;;
  "vpc_peering")
    export TF_VAR_endpoint_access='{"type":"vpc_peering"}'
    export LOCUST_TEST_TYPE="grpc"  # Changed to grpc for vpc_peering
    echo "Configuring VPC peering endpoint access with gRPC tests"
    
    # Validate required VPC peering parameters
    if [[ -z "${VPC_NETWORK_NAME}" ]]; then
      echo "ERROR: NETWORK_NAME must be set for vpc_peering access type"
      exit 1
    fi
    
    if [[ -z "${PEERING_RANGE_NAME}" ]]; then
      echo "ERROR: PEERING_RANGE_NAME must be set for vpc_peering access type"
      exit 1
    fi
    
    # Enable Service Networking API (required for VPC peering)
    echo "Enabling Service Networking API for VPC peering..."
    gcloud services enable servicenetworking.googleapis.com --project="${PROJECT_ID}"
    ;;
  "private_service_connect")
    export TF_VAR_endpoint_access='{"type":"private_service_connect"}'
    export LOCUST_TEST_TYPE="grpc"
    echo "Configuring Private Service Connect endpoint access with gRPC tests"
    ;;
  *)
    echo "ERROR: Invalid ENDPOINT_ACCESS_TYPE. Must be one of: 'public', 'vpc_peering', 'private_service_connect'"
    exit 1
    ;;
esac


# Configure simplified network settings
NETWORK_CONFIG="{\"network_name\":\"${VPC_NETWORK_NAME:-default}\""
[[ -n "${SUBNETWORK}" ]] && NETWORK_CONFIG="${NETWORK_CONFIG},\"subnetwork\":\"${SUBNETWORK}\""
[[ -n "${MASTER_IPV4_CIDR_BLOCK}" ]] && NETWORK_CONFIG="${NETWORK_CONFIG},\"master_ipv4_cidr_block\":\"${MASTER_IPV4_CIDR_BLOCK}\""
[[ -n "${GKE_POD_SUBNET_RANGE}" ]] && NETWORK_CONFIG="${NETWORK_CONFIG},\"pod_subnet_range\":\"${GKE_POD_SUBNET_RANGE}\""
[[ -n "${GKE_SERVICE_SUBNET_RANGE}" ]] && NETWORK_CONFIG="${NETWORK_CONFIG},\"service_subnet_range\":\"${GKE_SERVICE_SUBNET_RANGE}\""
NETWORK_CONFIG="${NETWORK_CONFIG}}"
export TF_VAR_network_configuration="${NETWORK_CONFIG}"

# Validate subnet belongs to the specified VPC
if [[ -n "${SUBNETWORK}" && -n "${VPC_NETWORK_NAME}" ]]; then
  echo "Validating subnet ${SUBNETWORK} belongs to network ${VPC_NETWORK_NAME}..."
  
  # # Print all subnets for debugging
  # echo "Available subnets:"
  # gcloud compute networks subnets list --project="${PROJECT_ID}" --format="table(name,network,region)"
  
  # Extract just the subnet name from the full path if provided
  SUBNET_NAME=$(basename "${SUBNETWORK}")
  # echo "Looking for subnet: ${SUBNET_NAME}"
  
  # Get network URL format that GCP uses internally 
  NETWORK_URL="projects/${PROJECT_ID}/global/networks/${VPC_NETWORK_NAME}"
  # echo "Looking for network: ${NETWORK_URL}"
  
  # List specific subnet with details for debugging
  # echo "Detailed subnet info:"
  SUBNET_DETAILS=$(gcloud compute networks subnets describe ${SUBNET_NAME} \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --format="yaml" 2>/dev/null)
    
  # echo "${SUBNET_DETAILS}"
  
  # Extract network from subnet details
  SUBNET_NETWORK=$(echo "${SUBNET_DETAILS}" | grep "network:" | awk '{print $2}')
  # echo "Subnet belongs to network: ${SUBNET_NETWORK}"
  
  # Compare the networks
  if [[ "${SUBNET_NETWORK}" == *"${VPC_NETWORK_NAME}"* ]]; then
    echo "✅ Subnet validation successful: ${SUBNET_NAME} belongs to ${VPC_NETWORK_NAME}"
  else
    echo "❌ ERROR: Subnet '${SUBNET_NAME}' does not appear to belong to network '${VPC_NETWORK_NAME}'."
    echo "The subnet belongs to network: ${SUBNET_NETWORK}"
    echo "Please verify your network configuration."
    exit 1
  fi
fi

# Export VPC peering variables if needed
if [[ "${ENDPOINT_ACCESS_TYPE}" == "vpc_peering" ]]; then
  export TF_VAR_peering_range_name="${PEERING_RANGE_NAME}"
  export TF_VAR_peering_prefix_length="${PEERING_PREFIX_LENGTH:-16}"
fi
echo "network configuration is ${TF_VAR_network_configuration}"

# Determine if blended search is enabled (simplified)
if [[ -v SPARSE_EMBEDDING_NUM_DIMENSIONS && -v SPARSE_EMBEDDING_NUM_DIMENSIONS_WITH_VALUES ]]; then
  export blended_search="y"
  echo "Sparse embedding configuration detected - using blended search mode"
else
  export blended_search="n"
  echo "No sparse embedding configuration detected - using standard search mode"
fi

# Print configuration for verification
echo "==================================="
echo "Configuration Summary:"
echo "==================================="
echo "Project ID: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"
echo "Region: $REGION"
echo "Zone: $ZONE"
echo "Timestamp: $TIMESTAMP"
echo "Docker Image: $DOCKER_IMAGE"
echo "Index Dimensions: $INDEX_DIMENSIONS"
echo "Deployment ID: $DEPLOYMENT_ID"
echo "Endpoint Access Type: $ENDPOINT_ACCESS_TYPE"
echo "Locust Test Type: $LOCUST_TEST_TYPE"
echo "Network Name: ${VPC_NETWORK_NAME:-default}"
[[ -n "${SUBNETWORK}" ]] && echo "Subnetwork: $SUBNETWORK"

# Display VPC peering info if applicable
if [[ "${ENDPOINT_ACCESS_TYPE}" == "vpc_peering" ]]; then
  echo "VPC Peering Range Name: ${PEERING_RANGE_NAME}"
  echo "VPC Peering Prefix Length: ${PEERING_PREFIX_LENGTH:-16}"
fi

echo "Blended Search: $blended_search"
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

echo "External IP requested status = $need_external_ip"

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
if ! gcloud artifacts repositories describe locust-docker-repo-${DEPLOYMENT_ID} --location="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "Creating Artifact Registry repository..."
  gcloud artifacts repositories create locust-docker-repo-${DEPLOYMENT_ID} --repository-format=docker --location="${REGION}" --project="${PROJECT_ID}"
else
  echo "Artifact Registry repository already exists."
fi

# Create config directory
mkdir -p config
touch config/locust_config.env
# Set correct permissions
chmod 666 ./locust_tests/locust.py    
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

# Create or update terraform.tfvars with appropriate settings
cat <<EOF > terraform.tfvars
project_id     = "${PROJECT_ID}"
region         = "${REGION}"
project_number = "${PROJECT_NUMBER}"
deployment_id  = "${DEPLOYMENT_ID}"
locust_test_type = "${LOCUST_TEST_TYPE}"
# Network configuration using the new consolidated structure
network_configuration = {
  network_name = "${VPC_NETWORK_NAME:-default}"
  subnetwork = "${SUBNETWORK}"
  master_ipv4_cidr_block = "${MASTER_IPV4_CIDR_BLOCK:-172.16.0.0/28}"
  pod_subnet_range = "${GKE_POD_SUBNET_RANGE:-10.4.0.0/14}"
  service_subnet_range = "${GKE_SERVICE_SUBNET_RANGE:-10.0.32.0/20}"
}
EOF

# Add VPC peering variables if needed
if [[ "${ENDPOINT_ACCESS_TYPE}" == "vpc_peering" ]]; then
  cat <<EOF >> terraform.tfvars
peering_range_name = "${PEERING_RANGE_NAME}"
peering_prefix_length = ${PEERING_PREFIX_LENGTH:-16}
EOF
fi

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
image = "${DOCKER_IMAGE}"
EOF

# Add optional settings if defined (simplified)
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

# Display terraform.tfvars for verification
echo "Contents of terraform.tfvars:"
cat terraform.tfvars

# Initialize and apply just the vector search module
terraform init

echo "Deploying vector search in the Terraform workspace: $DEPLOYMENT_ID"
terraform apply -target=module.vector_search --auto-approve

# Extract crucial values from Terraform output (simplified error handling)
echo "Extracting Vector Search configuration..."
export VS_DIMENSIONS=${INDEX_DIMENSIONS}
export VS_DEPLOYED_INDEX_ID=$(terraform output -raw vector_search_deployed_index_id)
export VS_INDEX_ENDPOINT_ID=$(terraform output -raw vector_search_endpoint_id)

# Get public endpoint reliably without generating errors
if terraform output -raw vector_search_public_endpoint &>/dev/null; then
  VS_PUBLIC_ENDPOINT=$(terraform output -raw vector_search_public_endpoint)
  export VS_ENDPOINT_HOST="${VS_PUBLIC_ENDPOINT}"
  echo "Public endpoint is available at: ${VS_PUBLIC_ENDPOINT}"
else
  echo "Public endpoint is not available (expected with private endpoints)"
  export VS_ENDPOINT_HOST=""
fi

# Save these to a temporary file for Docker build
cd ..

# Create base locust_config.env with common settings
cat <<EOF > config/locust_config.env
INDEX_DIMENSIONS=${VS_DIMENSIONS}
DEPLOYED_INDEX_ID=${VS_DEPLOYED_INDEX_ID}
INDEX_ENDPOINT_ID=${VS_INDEX_ENDPOINT_ID}
ENDPOINT_HOST=${VS_ENDPOINT_HOST}
PROJECT_ID=${PROJECT_ID}
PROJECT_NUMBER=${PROJECT_NUMBER}
ENDPOINT_ACCESS_TYPE=${ENDPOINT_ACCESS_TYPE}
EOF

# Add blended search settings if enabled
if [[ "$blended_search" == "y" ]]; then
  cat <<EOF >> config/locust_config.env
SPARSE_EMBEDDING_NUM_DIMENSIONS=${SPARSE_EMBEDDING_NUM_DIMENSIONS}
SPARSE_EMBEDDING_NUM_DIMENSIONS_WITH_VALUES=${SPARSE_EMBEDDING_NUM_DIMENSIONS_WITH_VALUES}
NUM_NEIGHBORS=20
DENSE_EMBEDDING_NUM_DIMENSIONS=${VS_DIMENSIONS}
RETURN_FULL_DATAPOINT=False
NUM_EMBEDDINGS_PER_REQUEST=50
EOF
fi

# Extract PSC-specific values if PSC is enabled
if [[ "${ENDPOINT_ACCESS_TYPE}" == "private_service_connect" ]]; then
  echo "Extracting PSC configuration..."
  cd terraform
  export VS_PSC_ENABLED=true
  
  # Initialize variables
  VS_SERVICE_ATTACHMENT=""
  VS_PSC_IP=""
  VS_PSC_IP_WITH_PORT=""
  VS_MATCH_GRPC_ADDRESS=""
  
  # Get service attachment
  if terraform output -raw vector_search_service_attachment &>/dev/null; then
    VS_SERVICE_ATTACHMENT=$(terraform output -raw vector_search_service_attachment)
    echo "Service Attachment: ${VS_SERVICE_ATTACHMENT}"
  else
    echo "Warning: service_attachment not found in terraform output"
  fi
  
  # Get PSC IP address
  if terraform output -raw psc_address_ip &>/dev/null; then
    VS_PSC_IP=$(terraform output -raw psc_address_ip)
    VS_PSC_IP_WITH_PORT="${VS_PSC_IP}:10000"
    echo "PSC IP Address: ${VS_PSC_IP}"
  else
    echo "Warning: psc_address_ip not found in terraform output"
  fi
  
  # Get match_grpc_address
  if terraform output -raw vector_search_match_grpc_address &>/dev/null; then
    match_raw=$(terraform output -raw vector_search_match_grpc_address)
    # Add port if not already present
    if [[ "$match_raw" != *":"* && -n "$match_raw" ]]; then
      VS_MATCH_GRPC_ADDRESS="${match_raw}:10000"
    else
      VS_MATCH_GRPC_ADDRESS="$match_raw"
    fi
    echo "MATCH_GRPC_ADDRESS from Terraform: ${VS_MATCH_GRPC_ADDRESS}"
  else
    echo "Note: vector_search_match_grpc_address not available from Terraform"
  fi
  
  cd ..
  
  # Add PSC configuration to locust_config.env
  echo "PSC_ENABLED=true" >> config/locust_config.env
  
  if [[ -n "${VS_SERVICE_ATTACHMENT}" ]]; then
    echo "SERVICE_ATTACHMENT=${VS_SERVICE_ATTACHMENT}" >> config/locust_config.env
  fi
  
  if [[ -n "${VS_MATCH_GRPC_ADDRESS}" ]]; then
    echo "MATCH_GRPC_ADDRESS=${VS_MATCH_GRPC_ADDRESS}" >> config/locust_config.env
  fi
  
  if [[ -n "${VS_PSC_IP_WITH_PORT}" ]]; then
    echo "PSC_IP_ADDRESS=${VS_PSC_IP_WITH_PORT}" >> config/locust_config.env
  fi
else
  echo "PSC_ENABLED=false" >> config/locust_config.env
fi

# Display the contents of locust_config.env for verification
echo "Contents of locust_config.env:"
cat config/locust_config.env

# Phase 2: Build and push Docker image with the config
echo "Building and pushing Docker image..."

# Build and push the Docker image
gcloud builds submit --project=${PROJECT_ID} --tag ${DOCKER_IMAGE}

# Phase 3: Deploy the rest of the infrastructure
echo "Deploying remaining infrastructure..."
cd terraform

terraform workspace select $DEPLOYMENT_ID

echo "Deploying in the Terraform workspace: $DEPLOYMENT_ID"

# Create all GKE + Kubernetes resources
terraform apply --auto-approve

# Get output values safely
DEPLOYED_CLUSTER_SVC=""
DEPLOYED_CLUSTER_MAIN_NODE=""
DEPLOYED_CLUSTER_NAME=""
NGINX_PROXY_NAME=""
LOCUST_NAMESPACE=""


if terraform output -raw gke_cluster_name &>/dev/null; then
  DEPLOYED_CLUSTER_NAME=$(terraform output -raw gke_cluster_name)
  # Currently in terraform directory.
  cat << EOF >> "../${DEPLOYMENT_ID}_state.sh"
DEPLOYED_CLUSTER_NAME="${DEPLOYED_CLUSTER_NAME}"
EOF
  echo "GKE Cluster name: $DEPLOYED_CLUSTER_NAME"
fi

# Configure kubectl if we have a cluster name
if [[ -n "$DEPLOYED_CLUSTER_NAME" ]]; then
  echo "Configuring kubectl..."
  gcloud container clusters get-credentials $DEPLOYED_CLUSTER_NAME --project=${PROJECT_ID} --location=${REGION}
else
  echo "Warning: Unable to get GKE cluster name, skipping kubectl configuration"
fi


if terraform output -raw locust_master_svc_name &>/dev/null; then
  DEPLOYED_CLUSTER_SVC=$(terraform output -raw locust_master_svc_name)
  echo "GKE Cluster service: $DEPLOYED_CLUSTER_SVC"
fi

if terraform output -raw locust_master_node_name &>/dev/null; then
  DEPLOYED_CLUSTER_MAIN_NODE=$(terraform output -raw locust_master_node_name)
  echo "GKE Cluster main node: $DEPLOYED_CLUSTER_MAIN_NODE"
fi

if terraform output -raw nginx_proxy_name &>/dev/null; then
  NGINX_PROXY_NAME=$(terraform output -raw nginx_proxy_name)
  echo "NGINX proxy name: $NGINX_PROXY_NAME"
fi

# Get the namespace where resources are deployed
if terraform output -raw locust_namespace &>/dev/null; then
  LOCUST_NAMESPACE=$(terraform output -raw locust_namespace)
  echo "Locust resources namespace: $LOCUST_NAMESPACE"
else
  # Fallback - construct the namespace based on deployment ID
  LOCUST_NAMESPACE="${DEPLOYMENT_ID}-ns"
  LOCUST_NAMESPACE="${LOCUST_NAMESPACE//[^a-zA-Z0-9-]/-}"
  LOCUST_NAMESPACE="${LOCUST_NAMESPACE,,}"
  echo "Using constructed namespace: $LOCUST_NAMESPACE"
fi

echo "==================================="
echo "Deployment Complete!"
echo "==================================="

# Setup access if service name was found
if [[ -n "$DEPLOYED_CLUSTER_SVC" && -n "$DEPLOYED_CLUSTER_MAIN_NODE" && -n "$LOCUST_NAMESPACE" ]]; then
  if [[ "${need_external_ip,,}" =~ ^(y|yes)$ ]]; then
      # Always specify the namespace when interacting with Kubernetes resources
      kubectl -n $LOCUST_NAMESPACE delete svc ${DEPLOYED_CLUSTER_SVC} 
      kubectl -n $LOCUST_NAMESPACE apply -f - <<EOF
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
        EXTERNAL_IP=$(kubectl -n $LOCUST_NAMESPACE get svc ${DEPLOYED_CLUSTER_SVC} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
          break
        fi
        echo "Still waiting for external IP..."
        sleep 5
      done

      # Display the service information
      kubectl -n $LOCUST_NAMESPACE get svc ${DEPLOYED_CLUSTER_SVC}

      # Print the access URL with the actual IP
      echo "Access Locust UI at http://$EXTERNAL_IP:8089"
  else
      echo "Access Locust UI by running:"
      echo "gcloud compute ssh ${NGINX_PROXY_NAME} --project ${PROJECT_ID} --zone ${ZONE} -- -NL 8089:localhost:8089"
      echo "Then open http://localhost:8089 in your browser"
  fi
else
  echo "Warning: Unable to set up access to Locust UI due to missing service information"
fi

# Verify deployment - include namespace
echo "Verifying deployments in namespace $LOCUST_NAMESPACE..."
kubectl -n $LOCUST_NAMESPACE get deployments
