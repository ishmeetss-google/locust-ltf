variable "project_id" {
    type = string
    description = "The ID of the Google Cloud project where resources will be created."
}

variable "project_number" {
    type = number
    description = "Your numerical Google Cloud project number. Can be found by running `gcloud projects describe <project_id>` command."
}

variable "region" {
    type = string
    description = "The Google Cloud region where resources will be created."
    default = "us-central1"
}

variable "image" {
    type = string
    description = "Load testing image name."
    default = "us-central1-docker.pkg.dev/email2podcast/ishmeetss-locust-docker-repo/locust-image:LTF"
}