variable "project_id" {
    type = string
    description = "The ID of the Google Cloud project where resources will be created."
    default = "email2podcast"
}

variable "region" {
    type = string
    description = "The Google Cloud region where resources will be created."
    default = "us-central1"
}
