# Vector Search Load Testing Framework

This repository contains tools to deploy and run load tests against Google Cloud's Vector Search service. The framework sets up a Locust-based load testing environment in Google Kubernetes Engine (GKE) that can be used to measure performance and scalability of Vector Search deployments.

## Overview

The deployment script automates the following process:

## Step 1: Initial Setup and Configuration
- Verifies the existence of a configuration file
- Loads settings from `config.sh`
- Generates dynamic variables including timestamps and Docker image names
- Displays configuration summary for verification
- Prompts for user confirmation to proceed

## Step 2: Enable Required Google Cloud Services
- Enables necessary APIs:
  - AI Platform
  - Artifact Registry
  - Compute Engine
  - Autoscaling
  - Google Kubernetes Engine
  - IAM Credentials
  - Cloud Build
  - Identity and Access Management

## Step 3: Create Infrastructure for Docker Images
- Creates Artifact Registry repository for storing Docker images
- Sets up configuration directories and permissions

## Step 4: Deploy Vector Search Infrastructure
- Sets up Terraform workspace using the deployment ID
- Creates and configures `terraform.tfvars` based on config settings
- Initializes Terraform
- Applies Terraform configuration specifically for Vector Search components
- Extracts configuration values from deployed Vector Search resources

## Step 5: Build and Push Docker Image
- Builds a Docker image with the load testing code and configuration
- Pushes the image to Artifact Registry

## Step 6: Deploy GKE and Load Testing Framework
- Applies the full Terraform configuration for GKE and Locust
- Configures kubectl to interact with the newly created cluster

## Step 7: Configure Access to the Locust UI
- Creates appropriate Kubernetes service based on user preference for external IP
- For external IP:
  - Creates a LoadBalancer service
  - Waits for external IP assignment
  - Displays the URL for accessing the Locust UI
- For internal access:
  - Provides SSH command for port forwarding

## Prerequisites

- Google Cloud account with billing enabled
- Google Cloud CLI (`gcloud`) installed and configured
- Terraform installed
- Docker installed (for local development)
- Sufficient permissions to:
  - Create GKE clusters
  - Create Vector Search resources
  - Create Artifact Registry repositories
  - Deploy resources via Terraform

## Setup

1. Clone this repository to your local machine
2. Copy the configuration template to create your config file:
   ```bash
   cp config.template.sh config.sh
   ```
3. Edit `config.sh` with your specific configuration values

### Configuration Options

#### Required Configuration

| Parameter | Description |
|-----------|-------------|
| `PROJECT_ID` | Your Google Cloud project ID |
| `REGION` | Google Cloud region for resources |
| `ZONE` | Google Cloud zone for resources |
| `INDEX_DIMENSIONS` | Number of dimensions for vector embeddings |
| `DEPLOYMENT_ID` | Unique identifier for this deployment (used for Terraform workspace) |

#### Vector Search Index Options

You can either use an existing Vector Search index or create a new one:

**Option 1: Use Existing Index**
```bash
VECTOR_SEARCH_INDEX_ID="projects/PROJECT_ID/locations/REGION/indexes/INDEX_ID"
```

**Option 2: Create New Index**
```bash
VECTOR_SEARCH_INDEX_ID=""  # Leave empty
BUCKET_NAME="your-bucket-name"  # GCS bucket containing embedding data
EMBEDDING_PATH="path/to/embeddings"  # Path to embeddings within bucket
```

#### Deployment Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ENDPOINT_PUBLIC_ENDPOINT_ENABLED` | Whether to create a public endpoint | `true` |
| `INDEX_SHARD_SIZE` | Size of index shards | `"SHARD_SIZE_LARGE"` |
| `DEPLOYED_INDEX_RESOURCE_TYPE` | Resource allocation type | `"dedicated"` |
| `DEPLOYED_INDEX_DEDICATED_MACHINE_TYPE` | Machine type for dedicated deployments | `"n1-standard-32"` |
| `DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS` | Minimum number of replicas | `1` |
| `DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS` | Maximum number of replicas | `1` |

## Usage

1. Make sure your configuration is set correctly in `config.sh`
2. Run the deployment script:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```
3. Follow the prompts during deployment
4. When asked about external IP, choose based on your needs:
   - `y`: Creates a LoadBalancer service with an external IP (accessible from anywhere)
   - `n`: Sets up access via port forwarding (more secure)
5. Access the Locust UI using the provided URL or port forwarding command
6. Configure and run your load tests through the Locust web interface

## Cleanup

To destroy the deployed resources when done:

```bash
cd terraform
terraform workspace select <your-deployment-id>
terraform destroy --auto-approve
```

This will remove the GKE cluster, Vector Search resources, and other infrastructure components created by the script.