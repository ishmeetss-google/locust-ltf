$ gcloud artifacts repositories create ishmeetss-locust-docker-repo --repository-format=docker --location=us-central1 --description="Docker repository for the locust load testing"

$ gcloud builds submit --tag us-central1-docker.pkg.dev/email2podcast/ishmeetss-locust-docker-repo/locust-image:LTF

$ gcloud projects describe email2podcast

output:
createTime: '2023-08-28T17:25:48.645325Z'
lifecycleState: ACTIVE
name: email2podcast
parent:
  id: '246203784383'
  type: organization
projectId: email2podcast
projectNumber: '131502646301'

$ gcloud iam roles list | grep artifactregistry

output:
name: roles/artifactregistry.admin
name: roles/artifactregistry.containerRegistryMigrationAdmin
name: roles/artifactregistry.createOnPushRepoAdmin
name: roles/artifactregistry.createOnPushWriter
name: roles/artifactregistry.reader
name: roles/artifactregistry.repoAdmin
name: roles/artifactregistry.serviceAgent
name: roles/artifactregistry.writer

$ gcloud services enable container.googleapis.com

$ gcloud container clusters create ishmeetss-locust \
  --project email2podcast \
  --service-account ishmeetss-locust-fin@email2podcast.iam.gserviceaccount.com \
  --region us-central1 \
  --node-locations us-central1-a,us-central1-b,us-central1-c \
  --machine-type e2-standard-4 \
  --num-nodes 3

gcloud iam service-accounts get-iam-policy ishmeetss-locust-fin@email2podcast.iam.gserviceaccount.com --format json > ~/policy.json

gcloud container clusters delete ishmeetss-locust --region us-central1

$ gcloud components install gke-gcloud-auth-plugin / sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

$ sudo apt-get install kubectl

$ gcloud container clusters get-credentials ishmeetss-locust --location us-central1

$ gcloud container clusters resize ishmeetss-locust --location us-central1 --num-nodes=10

$ /google/src/cloud/ishmeetss/ishmeetss/google3/experimental/users/ishmeetss/locust/kustomize build manifests/ |kubectl apply -f -

$ export INTERNAL_LB_IP=$(kubectl get svc locust-master-web \
  -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

$ gcloud compute instances create-with-container locust-nginx-proxy-ishmeetss-fin \
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

$ gcloud compute ssh --zone "us-central1-a" "locust-nginx-proxy-ishmeetss" --project "email2podcast"

$ exit

$ gcloud compute ssh locust-nginx-proxy-ishmeetss-fin --project email2podcast --zone us-central1-a -- -NL 8089:localhost:8089
