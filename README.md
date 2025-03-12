# Vector Search Load Testing Framework

This framework enables distributed load testing for Vertex AI Vector Search endpoints using Locust running on Google Kubernetes Engine (GKE). The setup supports both public HTTP and private PSC/gRPC endpoint access methods.

## Overview

The framework provides a complete solution for testing Vector Search performance and scalability, including:

- Infrastructure setup via Terraform
- Simplified configuration management
- Automatic Vector Search index and endpoint deployment
- Distributed load testing with Locust
- Support for both HTTP and gRPC protocols
- Blended search (dense + sparse vectors) support

## Prerequisites

- Google Cloud project with billing enabled
- `gcloud` CLI installed and configured
- Terraform installed (v1.0.0+)
- Access to create GKE clusters and Vertex AI resources
- Permissions to create service accounts and IAM roles

## Configuration Options

The framework is configured using a single `config.sh` file. Copy the template file and modify as needed:

```bash
cp config.template.sh config.sh
nano config.sh
```

### Required Configuration

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| `PROJECT_ID` | Google Cloud project ID | `"your-project-id"` |
| `REGION` | Region for resource deployment | `"us-central1"` |
| `ZONE` | Zone for compute resources | `"us-central1-a"` |
| `DEPLOYMENT_ID` | Unique identifier for this deployment | `"vs-load-test-1"` |
| `INDEX_DIMENSIONS` | Vector dimensions in the index | `768` |
| `ENDPOINT_ACCESS_TYPE` | Endpoint access method (options: "public", "private_vpc", "private_service_connect") | `"public"` |

### Index Source Configuration

Choose ONE of these options:

#### Option 1: Use existing index
```bash
VECTOR_SEARCH_INDEX_ID="projects/YOUR_PROJECT/locations/REGION/indexes/INDEX_ID"
```

#### Option 2: Create new index
```bash
BUCKET_NAME="your-embedding-bucket"
EMBEDDING_PATH="path/to/embeddings"
```

### Network Configuration (for private endpoints)

```bash
NETWORK_NAME="your-network"
SUBNETWORK="projects/YOUR_PROJECT/regions/REGION/subnetworks/your-subnet"
MASTER_IPV4_CIDR_BLOCK="172.16.0.0/28"
GKE_POD_SUBNET_RANGE="10.4.0.0/14"
GKE_SERVICE_SUBNET_RANGE="10.0.32.0/20"
```

### Sparse Embedding Configuration (for hybrid/blended search)

```bash
# Uncomment and set for hybrid/blended search
# SPARSE_EMBEDDING_NUM_DIMENSIONS=10000      # Total sparse dimensions
# SPARSE_EMBEDDING_NUM_DIMENSIONS_WITH_VALUES=200  # Non-zero dimensions
```

### Deployed Index Configuration

```bash
DEPLOYED_INDEX_RESOURCE_TYPE="dedicated"  # Options: "automatic", "dedicated"
DEPLOYED_INDEX_DEDICATED_MACHINE_TYPE="e2-standard-16"
DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS=2
DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS=5
```

### Additional Optional Settings

```bash
# Vector Search Index settings
INDEX_DISPLAY_NAME="my-vector-search-index"
INDEX_DESCRIPTION="Vector search index for testing"
INDEX_APPROXIMATE_NEIGHBORS_COUNT=150
INDEX_DISTANCE_MEASURE_TYPE="DOT_PRODUCT_DISTANCE"  # Options: "COSINE_DISTANCE", "EUCLIDEAN_DISTANCE", "DOT_PRODUCT_DISTANCE"
INDEX_ALGORITHM_CONFIG_TYPE="TREE_AH_ALGORITHM"  # Options: "TREE_AH_ALGORITHM", "BRUTE_FORCE_ALGORITHM"

# Endpoint settings
ENDPOINT_DISPLAY_NAME="my-vector-search-endpoint"
ENDPOINT_DESCRIPTION="Vector search endpoint for testing"
```

## Deployment Steps

1. **Setup Configuration**

   Copy the template and customize your configuration:
   ```bash
   cp config.template.sh config.sh
   nano config.sh
   ```

2. **Run the Deployment Script**

   Execute the deployment script:
   ```bash
   ./deploy.sh
   ```

   The script will:
   - Enable required Google Cloud APIs
   - Create an Artifact Registry repository
   - Build and deploy the Locust Docker image
   - Deploy Vector Search infrastructure
   - Create a GKE cluster
   - Deploy Locust to the GKE cluster

3. **Monitor Deployment**

   The deployment progress will be displayed in the console. Once completed, the script will provide instructions for accessing the Locust UI.

## Accessing the Locust UI

Based on your configuration, access to the Locust web interface is provided in one of two ways:

### With External IP

If you chose to create an external IP during deployment, access the UI directly at:
```
http://EXTERNAL_IP:8089
```

### Without External IP (Secure Tunnel)

If you chose not to use an external IP (more secure), use this command to create a tunnel:
```bash
gcloud compute ssh NGINX_PROXY_NAME --project PROJECT_ID --zone ZONE -- -NL 8089:localhost:8089
```

Then access the UI at:
```
http://localhost:8089
```

## Running Load Tests

1. **In the Locust UI:**
   - Set the number of users (concurrent clients)
   - Set the spawn rate (users started per second)
   - Start the test

2. **Monitor Results:**
   - Track RPS (requests per second)
   - Response times (min, max, average)
   - Failure rates
   - Download CSV reports for detailed analysis

3. **Advanced Configuration:**
   - For more advanced test scenarios, modify the `locust_tests/locust.py` file
   - Rebuild and redeploy using the deployment script

## Test Types

### HTTP Tests (Public Endpoints)

For `ENDPOINT_ACCESS_TYPE="public"`, the framework automatically configures HTTP-based load tests:
- Uses REST API access to Vector Search
- Supports OAuth2 authentication
- Suitable for testing public endpoints

### gRPC Tests (Private Service Connect)

For `ENDPOINT_ACCESS_TYPE="private_service_connect"`, the framework configures gRPC-based load tests:
- Uses high-performance gRPC protocol
- Supports direct private connectivity
- Higher throughput and lower latency
- Suitable for production-like testing

## Troubleshooting

### Common Issues

1. **Missing Configuration Values**
   
   Error: "Configuration value X not found"
   
   Solution: Check your `config.sh` file and ensure all required values are set.

2. **Deployment Fails at Vector Search Step**
   
   Error: "Failed to create Vector Search index"
   
   Possible Solutions:
   - Check Cloud Storage bucket and path
   - Verify project has Vertex AI API enabled
   - Check permissions

3. **GKE Cluster Creation Fails**
   
   Error: "Failed to create cluster"
   
   Possible Solutions:
   - Check quota limits in your project
   - Verify network/subnetwork configuration
   - Ensure service account has required permissions

4. **Cannot Access Locust UI**
   
   Solution:
   - Check if external IP was configured
   - Verify port forwarding command
   - Check firewall rules

### Logs and Debugging

- Terraform logs: `terraform/terraform.log`
- Locust pod logs: `kubectl logs -f deployment/locust-master`
- GKE cluster logs: GCP Console > Kubernetes Engine > Clusters > Logs

## Cleanup

To delete all resources created by this framework:

```bash
cd terraform
terraform destroy
```

Note: This will delete all resources included in the Terraform state, including any Vector Search indexes and endpoints.

## Additional Resources

- [Vertex AI Vector Search Documentation](https://cloud.google.com/vertex-ai/docs/vector-search/overview)
- [Locust Documentation](https://docs.locust.io/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)