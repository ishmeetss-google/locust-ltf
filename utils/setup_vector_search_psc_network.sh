#!/bin/bash
# setup_vector_search_psc_network.sh
# Script to set up VPC, subnet, and PSC for Vector Search load testing

# Exit on error
set -e

# Configuration - REPLACE THESE VALUES
PROJECT_ID="whisper-test-378918"
REGION="us-central1"
VPC_NAME="vertex-psc-network"
SUBNET_NAME="vertex-psc-subnet"
SUBNET_RANGE="10.0.0.0/24"
PSC_POLICY_NAME="vertex-psc-policy"

# Print configuration
echo "Setting up PSC for Vector Search with the following configuration:"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "VPC Name: $VPC_NAME"
echo "Subnet Name: $SUBNET_NAME"
echo "Subnet Range: $SUBNET_RANGE"
echo "PSC Policy Name: $PSC_POLICY_NAME"
echo ""

# Create VPC Network
echo "Creating VPC network..."
gcloud compute networks create $VPC_NAME \
    --project=$PROJECT_ID \
    --subnet-mode=custom

# Create Subnet
echo "Creating subnet..."
gcloud compute networks subnets create $SUBNET_NAME \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --region=$REGION \
    --range=$SUBNET_RANGE \
    --enable-private-ip-google-access \
    --purpose=PRIVATE

# Create Firewall Rules
echo "Creating firewall rules..."
# Allow internal communication within the VPC
gcloud compute firewall-rules create allow-internal-$VPC_NAME \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --action=ALLOW \
    --rules=tcp,udp,icmp \
    --source-ranges=$SUBNET_RANGE

# Allow traffic from GKE to Vertex AI
gcloud compute firewall-rules create allow-gke-to-vertex-$VPC_NAME \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --action=ALLOW \
    --rules=tcp:443,tcp:8080-8090 \
    --priority=1000 \
    --source-tags=gke-cluster \
    --target-tags=vertex-endpoint

# Allow health checks (required for some GCP services)
gcloud compute firewall-rules create allow-health-checks-$VPC_NAME \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --action=ALLOW \
    --rules=tcp \
    --source-ranges=35.191.0.0/16,130.211.0.0/22 \
    --target-tags=vertex-endpoint

# Allow traffic from GKE to Vertex AI
gcloud compute firewall-rules create allow-gke-to-vertex-$VPC_NAME \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --action=ALLOW \
    --rules=tcp:443,tcp:8080-8090,tcp:8443 \
    --priority=1000 \
    --source-tags=gke-cluster \
    --target-tags=vertex-endpoint

# Also add a specific rule for the PSC connection for Vector Search
gcloud compute firewall-rules create allow-psc-for-vector-search \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --action=ALLOW \
    --rules=tcp:443,tcp:8080-8090,tcp:8443,tcp:10000
    --priority=1000 \
    --source-ranges=$SUBNET_RANGE \
    --destination-ranges=0.0.0.0/0

echo ""
echo "Setup complete!"
echo "VPC: $VPC_NAME"
echo "Subnet: $SUBNET_NAME"
echo "PSC Policy: $PSC_POLICY_NAME"
echo ""
echo "You can now deploy your Vector Search index with PSC support."