# Vector Search Load Testing Framework

This framework enables distributed load testing for Vertex AI Vector Search endpoints using Locust running on Google Kubernetes Engine (GKE). It allows simulating production-like workloads to benchmark performance, analyze scalability, and validate deployment configurations.

## Overview

The framework provides a complete solution for testing Vector Search performance and scalability, including:

- Infrastructure setup via Terraform
- Simplified configuration management
- Automatic Vector Search index and endpoint deployment
- Distributed load testing with Locust
- Support for both HTTP and gRPC protocols
- Blended search (dense + sparse vectors) support
- Network isolation with VPC options
- Multiple deployment topologies for comparing different configurations

## Use Cases

- **Performance Benchmarking**: Measure throughput (QPS) and latency across different Vector Search configurations
- **Capacity Planning**: Determine the right machine type and replica count for your production workload
- **Scaling Validation**: Test autoscaling capabilities under varying loads
- **Network Topology Testing**: Compare public vs. private endpoint performance
- **Cost Optimization**: Find the most cost-effective configuration for your performance requirements
- **Protocol Comparison**: Compare HTTP vs. gRPC performance characteristics
- **Production Readiness**: Validate your configuration can handle expected traffic spikes

## Prerequisites

- Google Cloud project with billing enabled
- `gcloud` CLI installed and configured
- Terraform installed (v1.0.0+)
- Access to create GKE clusters and Vertex AI resources
- Permissions to create service accounts and IAM roles

## Quick Start

For those who want to get started immediately:

1. Copy the configuration template:
   ```bash
   cp config.template.sh config.sh
   ```

2. Edit the minimum required settings:
   ```bash
   nano config.sh
   
   # Required settings:
   PROJECT_ID="your-project-id"
   REGION="us-central1"
   ZONE="us-central1-a"
   DEPLOYMENT_ID="vs-load-test-1"
   INDEX_DIMENSIONS=1536
   ENDPOINT_ACCESS_TYPE="public"  # Start with public for simplicity
   
   # Use an existing index (easier to start with):
   VECTOR_SEARCH_INDEX_ID="projects/your-project/locations/us-central1/indexes/your-index-id"
   ```

3. Run the deployment:
   ```bash
   ./deploy_vvs_load_testing_framework.sh
   ```

4. Access the Locust UI using the URL provided at the end of deployment.

## Detailed Configuration Options

The framework is highly configurable to simulate various production scenarios. Here are the configuration options organized by category:

### Core Configuration

| Parameter | Description | Example Value | Personas |
|-----------|-------------|---------------|----------|
| `PROJECT_ID` | Google Cloud project ID | `"your-project-id"` | All |
| `REGION` | Region for resource deployment | `"us-central1"` | All |
| `ZONE` | Zone for compute resources | `"us-central1-a"` | All |
| `DEPLOYMENT_ID` | Unique identifier for this deployment | `"vs-load-test-1"` | All |
| `INDEX_DIMENSIONS` | Vector dimensions in the index | `768` (Cohere) or `1536` (OpenAI) | All |

### Deployment Topology

| Parameter | Description | Example Value | Recommended For |
|-----------|-------------|---------------|----------------|
| `ENDPOINT_ACCESS_TYPE` | Endpoint access method | `"public"` | Simple testing, initial benchmarks |
| | | `"private_service_connect"` | Production simulation, security-focused testing |
| | | `"vpc_peering"` | Legacy private deployments, network isolation |

### Index Source Configuration (Choose ONE option)

For using an existing index:
```bash
VECTOR_SEARCH_INDEX_ID="projects/YOUR_PROJECT/locations/REGION/indexes/INDEX_ID"
```

For creating a new index:
```bash
BUCKET_NAME="your-embedding-bucket"
EMBEDDING_PATH="path/to/embeddings"
```

### Network Configuration

Required for private endpoints (`"private_service_connect"` or `"vpc_peering"`):

```bash
VPC_NETWORK_NAME="your-network"                                         # Network name
SUBNETWORK="projects/YOUR_PROJECT/regions/REGION/subnetworks/your-subnet" # Subnet for resources
MASTER_IPV4_CIDR_BLOCK="172.16.0.0/28"                                  # GKE control plane IP range
GKE_POD_SUBNET_RANGE="10.4.0.0/14"                                      # Pod IP range
GKE_SERVICE_SUBNET_RANGE="10.0.32.0/20"                                 # Service IP range
```

### Performance Testing Features

#### Vector Search Configuration

```bash
# Index configuration
INDEX_SHARD_SIZE="SHARD_SIZE_LARGE"                   # Options: SMALL, MEDIUM, LARGE
INDEX_APPROXIMATE_NEIGHBORS_COUNT=150                 # Impacts accuracy vs. speed
INDEX_DISTANCE_MEASURE_TYPE="DOT_PRODUCT_DISTANCE"    # Vector similarity measure
INDEX_ALGORITHM_CONFIG_TYPE="tree_ah_config"          # Algorithm: tree_ah_config or brute_force_config

# Deployed index resources
DEPLOYED_INDEX_RESOURCE_TYPE="dedicated"                    # Options: "automatic", "dedicated"
DEPLOYED_INDEX_DEDICATED_MACHINE_TYPE="e2-standard-16"      # Machine type
DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS=2                     # Min replica count
DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS=5                     # Max replica count (for autoscaling)
```

#### Blended Search (Optional)

Enables testing with both dense and sparse embeddings:

```bash
SPARSE_EMBEDDING_NUM_DIMENSIONS=10000       # Total sparse dimensions
SPARSE_EMBEDDING_NUM_DIMENSIONS_WITH_VALUES=200   # Non-zero dimensions per vector
```

#### Load Testing Configuration

```bash
# Locust worker configuration for higher throughput tests
WORKER_MIN_REPLICAS=5             # Starting worker count 
WORKER_MAX_REPLICAS=1000          # Maximum worker count
WORKER_CPU_THRESHOLD=30           # CPU threshold % for scaling
```

## Production Simulation Recipes

Here are common configurations for simulating specific production scenarios:

### High-Throughput Public Endpoint

For testing maximum QPS with public endpoints:

```bash
ENDPOINT_ACCESS_TYPE="public"
INDEX_SHARD_SIZE="SHARD_SIZE_LARGE"
DEPLOYED_INDEX_RESOURCE_TYPE="dedicated"
DEPLOYED_INDEX_DEDICATED_MACHINE_TYPE="n1-standard-32"
DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS=5
DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS=10
WORKER_MIN_REPLICAS=10
```

### Secure Enterprise Deployment

For simulating enterprise production with private connectivity:

```bash
ENDPOINT_ACCESS_TYPE="private_service_connect"
INDEX_SHARD_SIZE="SHARD_SIZE_LARGE"
DEPLOYED_INDEX_RESOURCE_TYPE="dedicated"
DEPLOYED_INDEX_DEDICATED_MACHINE_TYPE="n1-standard-16"
DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS=3
DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS=8
```

### Cost-Optimized Configuration

For testing the most cost-effective setup for moderate loads:

```bash
ENDPOINT_ACCESS_TYPE="public"
INDEX_SHARD_SIZE="SHARD_SIZE_MEDIUM"
DEPLOYED_INDEX_RESOURCE_TYPE="dedicated"
DEPLOYED_INDEX_DEDICATED_MACHINE_TYPE="e2-standard-8"
DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS=2
DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS=5
```

### Multi-Region Testing

For comparing performance across regions, deploy multiple instances:

```bash
# First deployment
DEPLOYMENT_ID="us-central1-test"
REGION="us-central1"
ZONE="us-central1-a"

# Second deployment (in different terminal)
DEPLOYMENT_ID="us-east1-test"
REGION="us-east1"
ZONE="us-east1-b"
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
   ./deploy_vvs_load_testing_framework.sh
   ```

   The script will:
   - Enable required Google Cloud APIs
   - Create an Artifact Registry repository
   - Build and deploy the Locust Docker image
   - Deploy Vector Search infrastructure
   - Create a GKE cluster with proper namespace isolation
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

## Running Effective Load Tests

### 1. Planning Your Test

Before running a test, define your goals:
- **Baseline Performance**: What's the normal expected QPS?
- **Peak Load**: What's the maximum load you need to support?
- **Sustained Load**: What continuous load should you test?
- **Metrics to Capture**: Response time, error rates, throughput

### 2. Configuring Locust Tests

In the Locust UI:

- **Number of Users**: The number of concurrent clients making requests
  - Start small (10-20) and gradually increase
  - For production simulations, scale to 100+ users
  
- **Spawn Rate**: How quickly to add users
  - Start slow (1-2 users/sec) to avoid overloading
  - Increase for stress testing (5-10 users/sec)
  
- **Test Duration**: Run tests long enough to observe stable behavior
  - 5-10 minutes for initial tests
  - 30+ minutes for performance validation

### 3. Monitoring During Tests

Watch these metrics during your test:

- **RPS (Requests Per Second)**: Overall throughput
- **Response Time**: Median and 95th percentile latency
- **Failure Rate**: Should ideally remain at 0%
- **CPU/Memory Usage**: Via GCP console 

### 4. Analyzing Results

After testing, analyze the results to make configuration decisions:

- **Latency vs. Throughput Curves**: Understand performance trade-offs
- **Scaling Efficiency**: Check if adding replicas improves throughput linearly
- **Cost-Performance Ratio**: Calculate cost per 1000 queries
- **Error Patterns**: Identify any bottlenecks

Download the CSV reports from Locust for detailed analysis.

## Advanced Customization

### Customizing Load Testing Patterns

To modify the testing behavior:

1. Edit the Locust test file:
   ```bash
   nano locust_tests/locust.py
   ```

2. Customize the query patterns, vector dimensions, embedding values, or test logic

3. Rebuild and redeploy:
   ```bash
   ./deploy_vvs_load_testing_framework.sh
   ```

### Testing Different Query Types

The framework supports testing different Vector Search query configurations:

- **Nearest Neighbor Count**: Adjust with `--num-neighbors` parameter in Locust
- **Sparse + Dense Vectors**: Configure with sparse embedding parameters
- **Tree-AH Parameters**: Test leaf node search percentages
- **Different Distance Metrics**: Test performance across metrics

## Troubleshooting

### Common Issues

1. **Missing Configuration Values**
   
   Error: "Configuration value X not found"
   
   Solution: Check your `config.sh` file and ensure all required values are set.

2. **Network/Subnet Mismatch**

   Error: "Subnetwork X is not valid for Network Y"
   
   Solution: Ensure the subnet specified in SUBNETWORK belongs to the VPC specified in VPC_NETWORK_NAME.

3. **Master CIDR Block Conflict**

   Error: "Conflicting IP cidr range: Invalid IPCidrRange"
   
   Solution: Use a different MASTER_IPV4_CIDR_BLOCK for each deployment in the same VPC.

4. **Deployment Fails at Vector Search Step**
   
   Error: "Failed to create Vector Search index"
   
   Possible Solutions:
   - Check Cloud Storage bucket and path
   - Verify project has Vertex AI API enabled
   - Check permissions

5. **GKE Cluster Creation Fails**
   
   Error: "Failed to create cluster"
   
   Possible Solutions:
   - Check quota limits in your project
   - Verify network/subnetwork configuration
   - Ensure service account has required permissions

6. **PSC Address Creation Fails**

   Error: "Invalid value for field 'resource.network'"
   
   Solution: For PSC addresses, only specify subnetwork, not network.

7. **Cannot Access Locust UI**
   
   Solution:
   - Check if external IP was configured
   - Verify port forwarding command
   - Check firewall rules

8. **Kubernetes Resources Not Found**

   Error: "Error: services 'X' not found"
   
   Solution: Ensure you're using the correct namespace with kubectl commands:
   ```bash
   kubectl -n DEPLOYMENT_ID-ns get pods
   ```

9. **Workers Not Scaling**

   Problem: Worker count remains at minimum despite high load
   
   Solutions:
   - Check worker CPU utilization (should approach threshold %)
   - Check HPA configuration
   - Increase test load or lower CPU threshold

### Logs and Debugging

- Terraform logs: `terraform/terraform.log`
- Locust pod logs: `kubectl -n DEPLOYMENT_ID-ns logs -f deployment/DEPLOYMENT_ID-master`
- GKE cluster logs: GCP Console > Kubernetes Engine > Clusters > Logs
- Vector Search metrics: Vertex AI > Vector Search > Endpoints > Monitoring

## Multiple Deployments

You can run multiple load test deployments in the same project to compare different configurations:

1. Using different `DEPLOYMENT_ID` values
2. Using different `MASTER_IPV4_CIDR_BLOCK` ranges for GKE clusters
3. Optionally using different `VPC_NETWORK_NAME` values

For example:
```bash
# Deployment 1 - OpenAI embeddings
DEPLOYMENT_ID="openai_test"
INDEX_DIMENSIONS=1536
MASTER_IPV4_CIDR_BLOCK="172.16.0.0/28"

# Deployment 2 - Cohere embeddings  
DEPLOYMENT_ID="cohere_test"
INDEX_DIMENSIONS=768
MASTER_IPV4_CIDR_BLOCK="172.16.0.16/28"

# Deployment 3 - Custom configuration
DEPLOYMENT_ID="custom_test"
INDEX_DIMENSIONS=384
MASTER_IPV4_CIDR_BLOCK="172.16.0.32/28"
```

## Cleanup

To delete all resources created by this framework:

```bash
cd terraform
terraform workspace select DEPLOYMENT_ID
terraform destroy
```

Note: This will delete all resources included in the Terraform state, including any Vector Search indexes and endpoints.

## Additional Resources

- [Vertex AI Vector Search Documentation](https://cloud.google.com/vertex-ai/docs/vector-search/overview)
- [Locust Documentation](https://docs.locust.io/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Private Service Connect Documentation](https://cloud.google.com/vpc/docs/private-service-connect)
- [Vector Search Performance Best Practices](https://cloud.google.com/vertex-ai/docs/vector-search/optimize-vector-search-performance)
