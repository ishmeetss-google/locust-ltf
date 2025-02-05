# Setting Up Distributed Load Testing with Locust on Google Cloud Platform

This guide demonstrates how to set up a distributed load testing environment using Locust on Google Kubernetes Engine (GKE). We'll create a Docker repository, build and deploy a Locust container, set up a GKE cluster, and configure networking for accessing the Locust web interface. This setup enables scalable performance testing of your applications.

## Step 1: Create Docker Repository
Create an Artifact Registry repository to store our Locust Docker images.
```bash
gcloud artifacts repositories create ishmeetss-locust-docker-repo --repository-format=docker --location=us-central1 --description="Docker repository for the locust load testing"
```

## Step 2: Build and Submit Docker Image
Build and push the Locust Docker image to our repository.
```bash
gcloud builds submit --tag us-central1-docker.pkg.dev/email2podcast/ishmeetss-locust-docker-repo/locust-image:LTF
```

## Step 3: Verify Project Configuration
Check project details to ensure proper setup and access.
```bash
gcloud projects describe email2podcast
```

## Step 4: Check Available IAM Roles
Verify available Artifact Registry roles for proper permissions management.
```bash
gcloud iam roles list | grep artifactregistry
```

## Step 5: Enable Container Services
Enable the Container API for GKE cluster creation.
```bash
gcloud services enable container.googleapis.com
```

## Step 6: Create GKE Cluster
Set up a distributed GKE cluster for running Locust tests.
```bash
gcloud container clusters create ishmeetss-locust \
  --project email2podcast \
  --service-account ishmeetss-locust-fin@email2podcast.iam.gserviceaccount.com \
  --region us-central1 \
  --node-locations us-central1-a,us-central1-b,us-central1-c \
  --machine-type e2-standard-4 \
  --num-nodes 3
```

## Step 7: Configure IAM Policies
Export service account IAM policies for review and management.
```bash
gcloud iam service-accounts get-iam-policy ishmeetss-locust-fin@email2podcast.iam.gserviceaccount.com --format json > ~/policy.json
```

## Step 8: Install Required Tools
Install necessary tools for cluster management.
```bash
gcloud components install gke-gcloud-auth-plugin
sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin
sudo apt-get install kubectl
```

## Step 9: Configure Cluster Access
Set up authentication for the GKE cluster.
```bash
gcloud container clusters get-credentials ishmeetss-locust --location us-central1
```

## Step 10: Scale Cluster
Increase the number of nodes for higher load testing capacity.
```bash
gcloud container clusters resize ishmeetss-locust --location us-central1 --num-nodes=10
```

## Step 11: Deploy Locust
Apply the Locust configuration to the cluster.
```bash
/google/src/cloud/ishmeetss/ishmeetss/google3/experimental/users/ishmeetss/locust/kustomize build manifests/ |kubectl apply -f -
```

## Step 12: Set Up Load Balancer
Configure load balancer access for the Locust web interface.
```bash
export INTERNAL_LB_IP=$(kubectl get svc locust-master-web \
  -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

## Step 13: Create Nginx Proxy
Set up an Nginx proxy for accessing the Locust interface.
```bash
gcloud compute instances create-with-container locust-nginx-proxy-ishmeetss-fin \
  --project email2podcast \
  --zone us-central1-a \
  --container-image gcr.io/cloud-marketplace/google/nginx1:latest \
  --container-mount-host-path=host-path=/tmp/server.conf,mount-path=/etc/nginx/conf.d/default.conf \
  --metadata=startup-script="#! /bin/bash
    cat <<EOF  > /tmp/server.conf
    server {
        listen 8089;
        location / {
            proxy_pass http://${INTERNAL_LB_IP}:8089;
        }
    }
EOF"
```

## Step 14: Configure Port Forwarding
Set up local port forwarding to access the Locust web interface.
```bash
gcloud compute ssh locust-nginx-proxy-ishmeetss-fin --project email2podcast --zone us-central1-a -- -NL 8089:localhost:8089
```