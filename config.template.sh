#!/bin/bash
# Configuration template file - copy to config.sh and modify as needed
# This file will be committed to the repository as a template

# Basic configuration
PROJECT_ID="your-project-id"
REGION="us-central1"
ZONE="us-central1-a"
INDEX_DIMENSIONS=768
INDEX_DIMENSIONS=768
# DEPLOYMENT_ID: Unique identifier for the resources deployed in this run
# Format: [a-z0-9][-a-z0-9]* (must start with letter/number, can contain underscores)
DEPLOYMENT_ID="identifer-for-deployed-resources"

# Set one of these options:
# Option 1: Use existing index
VECTOR_SEARCH_INDEX_ID=""  # e.g. "projects/PROJECT_ID/locations/REGION/indexes/4705835000090591232"

# Option 2: Create new index (leave VECTOR_SEARCH_INDEX_ID empty to use these)
BUCKET_NAME="your-embedding-bucket"
EMBEDDING_PATH="your-embedding-folder"


#Endpoint configuration settings
ENDPOINT_PUBLIC_ENDPOINT_ENABLED=true
ENDPOINT_ENABLE_PRIVATE_SERVICE_CONNECT=false  # Set to true to enable PSC

# Optional Deployed Index configuration settings
DEPLOYED_INDEX_RESOURCE_TYPE="dedicated"  # Options: automatic, dedicated

# Optional Vector Search Index configuration settings
# INDEX_DISPLAY_NAME="my-vector-search-index"
# INDEX_DESCRIPTION="Vector search index for embeddings"
# INDEX_LABELS='{ "environment": "dev", "purpose": "benchmarking" }'
# INDEX_APPROXIMATE_NEIGHBORS_COUNT=150
# INDEX_DISTANCE_MEASURE_TYPE="DOT_PRODUCT_DISTANCE"  # Options: COSINE_DISTANCE, EUCLIDEAN_DISTANCE, DOT_PRODUCT_DISTANCE
# FEATURE_NORM_TYPE="UNIT_L2_NORM"  # Options: NONE, UNIT_L2_NORM
# INDEX_ALGORITHM_CONFIG_TYPE="TREE_AH_ALGORITHM"  # Options: TREE_AH_ALGORITHM, BRUTE_FORCE_ALGORITHM
# INDEX_TREE_AH_LEAF_NODE_EMBEDDING_COUNT=1000
# INDEX_TREE_AH_LEAF_NODES_TO_SEARCH_PERCENT=10
# INDEX_UPDATE_METHOD="BATCH_UPDATE"  # Options: BATCH_UPDATE, STREAM_UPDATE

# Optional Endpoint configuration settings
# ENDPOINT_DISPLAY_NAME="my-vector-search-endpoint"
# ENDPOINT_DESCRIPTION="Vector search endpoint for querying"
# ENDPOINT_LABELS='{ "environment": "dev", "purpose": "benchmarking" }'
# ENDPOINT_NETWORK="projects/your-project/global/networks/your-vpc"
# ENDPOINT_ENABLE_PRIVATE_SERVICE_CONNECT=false
# ENDPOINT_PUBLIC_ENDPOINT_ENABLED=true
# ENDPOINT_CREATE_TIMEOUT="60m"
# ENDPOINT_UPDATE_TIMEOUT="60m"
# ENDPOINT_DELETE_TIMEOUT="60m"

# Optional Deployed Index configuration settings
# DEPLOYED_INDEX_ID="my-deployed-index"
# DEPLOYED_INDEX_RESOURCE_TYPE="dedicated"  # Options: automatic, dedicated
# DEPLOYED_INDEX_DEDICATED_MACHINE_TYPE="e2-highmen-16"
# DEPLOYED_INDEX_DEDICATED_MIN_REPLICAS=2
# DEPLOYED_INDEX_DEDICATED_MAX_REPLICAS=5
# DEPLOYED_INDEX_AUTOMATIC_MIN_REPLICAS=2
# DEPLOYED_INDEX_AUTOMATIC_MAX_REPLICAS=5
# DEPLOYED_INDEX_RESERVED_IP_RANGES='["ip-range-name-1", "ip-range-name-2"]'
# DEPLOYED_INDEX_CREATE_TIMEOUT="60m"
# DEPLOYED_INDEX_UPDATE_TIMEOUT="60m"
# DEPLOYED_INDEX_DELETE_TIMEOUT="60m"

# GKE and PSC Network Configuration
# PSC_NETWORK_NAME="vertex-psc-network"     # Network name to use for PSC
# SUBNETWORK=""                             # Format: projects/{project}/regions/{region}/subnetworks/{subnetwork}
# USE_PRIVATE_ENDPOINT=false                # Whether to use a private endpoint for GKE
# MASTER_IPV4_CIDR_BLOCK="172.16.0.0/28"    # IP range for GKE master
# GKE_POD_SUBNET_RANGE="10.4.0.0/14"        # IP range for GKE pods
# GKE_SERVICE_SUBNET_RANGE="10.0.32.0/20"   # IP range for GKE services