#!/bin/bash
set -e  # Exit on any error

# Basic configuration
export PROJECT_ID="vertex-platform"
export REGION="us-central1"
export ZONE="us-central1-a"
export DOCKER_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/locust-docker-repo/locust-load-test:LTF-v2"
export INDEX_DIMENSIONS=768
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")



# Set one of these options:
# Option 1: Use existing index
export VECTOR_SEARCH_INDEX_ID="projects/${PROJECT_ID}/locations/${REGION}/indexes/1688423249752358912"
# OR
# Option 2: Create new index (uncomment these if not using existing index)
# export BUCKET_NAME="your-bucket-name"
# export EMBEDDING_PATH="path/to/embeddings"


# Enable required services
echo "Enabling required Google Cloud services..."
gcloud services enable aiplatform.googleapis.com \
  artifactregistry.googleapis.com \
  compute.googleapis.com \
  autoscaling.googleapis.com \
  container.googleapis.com \
  iamcredentials.googleapis.com \
  cloudbuild.googleapis.com \
  iam.googleapis.com

# Create Artifact Registry repository
echo "Creating Artifact Registry repository..."
gcloud artifacts repositories create locust-docker-repo --repository-format=docker --location=${REGION} --project=${PROJECT_ID} || true

# Create config directory
mkdir -p config

# Phase 1: Deploy Vector Search infrastructure first
echo "Deploying Vector Search infrastructure..."
cd terraform

# Create or update terraform.tfvars with appropriate settings
cat <<EOF > terraform.tfvars
project_id     = "${PROJECT_ID}"
region         = "${REGION}"
project_number = "${PROJECT_NUMBER}"

EOF

# Check if we're using an existing index or need to create a new one
if [[ -n "${VECTOR_SEARCH_INDEX_ID}" ]]; then
  # Using existing index
  echo "vector_search_index_id = \"${VECTOR_SEARCH_INDEX_ID}\"" >> terraform.tfvars
  echo "Using existing Vector Search index: ${VECTOR_SEARCH_INDEX_ID}"
else
  # Using bucket and path for new index
  echo "existing_bucket_name = \"${BUCKET_NAME}\"" >> terraform.tfvars
  echo "embedding_data_path = \"${EMBEDDING_PATH}\"" >> terraform.tfvars
  echo "Creating new Vector Search index from data in gs://${BUCKET_NAME}/${EMBEDDING_PATH}"
fi

# Add other common settings
cat <<EOF >> terraform.tfvars
index_dimensions = ${INDEX_DIMENSIONS}
endpoint_public_endpoint_enabled = true
deployed_index_resource_type = "automatic"
image = "${DOCKER_IMAGE}"
EOF

# Initialize and apply just the vector search module
terraform init
terraform apply -target=module.vector_search -auto-approve

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

# Set correct permissions
chmod 666 config/locust_config.env

# Phase 2: Build and push Docker image with the config
echo "Building and pushing Docker image..."

# Build and push the Docker image
gcloud builds submit --project=${PROJECT_ID} --tag ${DOCKER_IMAGE}

# Phase 3: Deploy the rest of the infrastructure
echo "Deploying remaining infrastructure..."
cd terraform

# Apply the full infrastructure
terraform apply -auto-approve

# Configure kubectl
echo "Configuring kubectl..."
gcloud container clusters get-credentials ltf-autopilot-cluster --project=${PROJECT_ID} --location=${REGION}

# Verify the deployments
echo "Verifying deployments..."
kubectl get deployments


echo "==================================="
echo "Deployment Complete!"
echo "==================================="
echo "Access Locust UI by running:"
echo "The nginx proxy is managed by Terraform and will be created automatically"

echo "==================================="
echo "Deployment Complete!"
echo "==================================="
echo "Access Locust UI by running the command from the Terraform output:"
echo "terraform output -raw locust_ui_access_instructions"
echo "gcloud compute ssh ltf-nginx-proxy --project ${PROJECT_ID} --zone ${ZONE} -- -NL 8089:localhost:8089"
echo "Then open http://localhost:8089 in your browser"