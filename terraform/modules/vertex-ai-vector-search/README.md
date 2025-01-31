# Vertex AI Vector Search Terraform Module

This Terraform module deploys a Vertex AI Vector Search Index, Index Endpoint, and Deployed Index on Google Cloud Platform (GCP). It is designed to be highly flexible and configurable for various deployment scenarios, including load testing.

## Prerequisites

Before you begin, ensure you have the following:

1.  **GCP Project:** You need an active Google Cloud Platform project.
2.  **GCP Credentials:**  Ensure your environment is configured with GCP credentials that have the necessary permissions to create Vertex AI Index, Index Endpoint, Deploy Index, and Cloud Storage access to your existing bucket.
3.  **Terraform Installed:**  Make sure you have Terraform installed on your local machine. ( [https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html) )
4.  **Existing Cloud Storage Bucket with Embeddings:** This module is designed to use a pre-existing Cloud Storage bucket where you have already uploaded your vector embeddings and index data.
5.  **VPC Network (If using VPC Peering):** If you plan to deploy the Index Endpoint with VPC Peering (`endpoint_network` variable), you need to have a configured VPC network in your GCP project that you intend to peer with.  Refer to the GCP documentation for setting up VPC Peering for Vertex AI Vector Search: [VPC Peering for Vertex AI Vector Search](https://cloud.google.com/vertex-ai/docs/vector-search/setup/vpc).
6.  **Private Service Connect (If using PSC):** If you plan to deploy the Index Endpoint with Private Service Connect (`endpoint_enable_private_service_connect` variable), refer to the GCP documentation for setup instructions: [Private Service Connect for Vertex AI Vector Search](https://cloud.google.com/vertex-ai/docs/vector-search/setup/private-service-connect).

## Files in this Module

*   **`main.tf`**:  Contains the Terraform resource definitions for the Vertex AI Vector Search Index, Endpoint, and Deployed Index.
*   **`variables.tf`**: Defines all the configurable variables for this module with descriptions and default values.
*   **`outputs.tf`**: Defines the output values exported by this module (e.g., endpoint IDs, index IDs).
*   **`README.md`**: This file, providing detailed documentation for the Vertex AI Vector Search module.

## Configuration Variables

The following variables are defined in `variables.tf` and **must be set in your root `terraform.tfvars` file** when using this module.

| Variable Name                                   | Description                                                                                                                                | Type    | Default                      | Example                                                                     |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ---------------------------- | --------------------------------------------------------------------------- |
| `project_id`                                    | GCP Project ID where resources will be deployed.                                                                                             | string  | **Required**                 | `your-gcp-project-id`                                                     |
| `region`                                        | GCP region for deploying Vertex AI resources (Index, Endpoint).                                                                          | string  | `"us-central1"`              | `"europe-west1"`                                                            |
| `existing_bucket_name`                          | Name of the **existing** Cloud Storage bucket containing your index data.                                                                  | string  | **Required**                 | `"your-embedding-bucket"`                                                 |
| `index_data_path`                               | Path within the `existing_bucket_name` where your index data is located.                                                                   | string  | `"contents"`                 | `"vector_data"`                                                             |
| `index_display_name`                            | Display name for the Vertex AI Index.                                                                                                       | string  | `"vector-search-index"`      | `"my-load-test-index"`                                                    |
| `index_description`                             | Description for the Vertex AI Index.                                                                                                        | string  | `"A Vector Index for load testing"` | `"Index for testing different distance metrics"`                             |
| `index_labels`                                  | Labels to apply to the Vertex AI Index.                                                                                                     | map(string) | `{}`                         | `{"environment" = "testing", "purpose" = "load-test"}`                      |
| `index_dimensions`                              | Number of dimensions for the vectors in your index.                                                                                        | number  | `128`                        | `768`                                                                       |
| `index_approximate_neighbors_count`             | Approximate neighbors count for indexing (algorithm parameter).                                                                              | number  | `150`                        | `200`                                                                       |
| `index_distance_measure_type`                   | Distance measure type for the index: `DOT_PRODUCT_DISTANCE`, `COSINE_DISTANCE`, `L2_SQUARED_DISTANCE`.                                    | string  | `"DOT_PRODUCT_DISTANCE"`     | `"COSINE_DISTANCE"`                                                         |
| `index_algorithm_config_type`                   | Algorithm configuration type: `tree_ah_config` or `brute_force_config`.                                                                   | string  | `"tree_ah_config"`           | `"brute_force_config"`                                                      |
| `index_tree_ah_leaf_node_embedding_count`        | Leaf node embedding count for the Tree-AH algorithm.                                                                                       | number  | `500`                        | `1000`                                                                      |
| `index_tree_ah_leaf_nodes_to_search_percent`     | Leaf nodes to search percent for the Tree-AH algorithm.                                                                                    | number  | `7`                          | `10`                                                                        |
| `index_update_method`                           | Index update method: `BATCH_UPDATE` or `STREAM_UPDATE`.                                                                                     | string  | `"BATCH_UPDATE"`             | `"STREAM_UPDATE"`                                                           |
| `index_create_timeout`                          | Timeout for Index creation.                                                                                                                | string  | `"2h"`                       | `"3h"`                                                                      |
| `index_update_timeout`                          | Timeout for Index update.                                                                                                                | string  | `"1h"`                       | `"1.5h"`                                                                    |
| `index_delete_timeout`                          | Timeout for Index deletion.                                                                                                                | string  | `"2h"`                       | `"3h"`                                                                      |
| `endpoint_display_name`                         | Display name for the Vertex AI Index Endpoint.                                                                                             | string  | `"vector-search-endpoint"`   | `"my-load-test-endpoint"`                                                 |
| `endpoint_description`                          | Description for the Vertex AI Index Endpoint.                                                                                              | string  | `"Endpoint for Vector Search load testing"` | `"Endpoint for testing different scaling options"`                         |
| `endpoint_labels`                               | Labels to apply to the Vertex AI Index Endpoint.                                                                                           | map(string) | `{}`                         | `{"environment" = "testing", "version" = "v1"}`                              |
| `endpoint_public_endpoint_enabled`              | Enable public endpoint access for the Index Endpoint. Set to `false` for private endpoints (VPC Peering or PSC).                          | bool    | `true`                       | `false`                                                                     |
| `endpoint_network`                              | (Optional) Full resource name of the VPC network for VPC Peering. Leave `null` for public endpoint or PSC.                               | string  | `null`                       | `"projects/my-project-id/global/networks/my-vpc-network"`                 |
| `endpoint_enable_private_service_connect`       | (Optional) Enable Private Service Connect (PSC) for the Index Endpoint. Set to `false` for public endpoint or VPC Peering.                | bool    | `false`                      | `true`                                                                      |
| `endpoint_create_timeout`                       | Timeout for Endpoint creation.                                                                                                             | string  | `"30m"`                      | `"45m"`                                                                     |
| `endpoint_update_timeout`                       | Timeout for Endpoint update.                                                                                                             | string  | `"30m"`                      | `"45m"`                                                                     |
| `endpoint_delete_timeout`                       | Timeout for Endpoint deletion.                                                                                                             | string  | `"30m"`                      | `"45m"`                                                                     |
| `deployed_index_id`                             | ID for the Deployed Index.                                                                                                                 | string  | `"deployed-vector-index"`    | `"load-test-deployed-index"`                                              |
| `deployed_index_resource_type`                  | Resource type for the Deployed Index: `dedicated` or `automatic`.                                                                         | string  | `"dedicated"`                | `"automatic"`                                                               |
| `deployed_index_dedicated_machine_type`         | Machine type for dedicated resources.                                                                                                      | string  | `"e2-standard-16"`           | `"n2-standard-32"`                                                          |
| `deployed_index_dedicated_min_replicas`         | Minimum replicas for dedicated resources.                                                                                                   | number  | `1`                          | `2`                                                                         |
| `deployed_index_dedicated_max_replicas`         | Maximum replicas for dedicated resources (for autoscaling).                                                                                   | number  | `3`                          | `10`                                                                        |
| `deployed_index_dedicated_cpu_utilization_target` | CPU utilization target percentage for autoscaling of dedicated resources.                                                                   | number  | `70`                         | `80`                                                                        |
| `deployed_index_automatic_min_replicas`         | Minimum replicas for automatic resources.                                                                                                   | number  | `1`                          | `0` (Can be zero for automatic scaling to zero)                               |
| `deployed_index_automatic_max_replicas`         | Maximum replicas for automatic resources.                                                                                                   | number  | `5`                          | `8`                                                                         |
| `deployed_index_reserved_ip_ranges`             | (Optional) List of reserved IP ranges for the Deployed Index.                                                                               | list(string) | `null`                       | `["10.0.0.0/29", "10.0.0.8/29"]`                                            |
| `deployed_index_create_timeout`                 | Timeout for Deployed Index creation.                                                                                                       | string  | `"2h"`                       | `"3h"`                                                                      |
| `deployed_index_update_timeout`                 | Timeout for Deployed Index update.                                                                                                       | string  | `"1h"`                       | `"1.5h"`                                                                    |
| `deployed_index_delete_timeout`                 | Timeout for Deployed Index deletion.                                                                                                       | string  | `"2h"`                       | `"3h"`                                                                      

## Getting Started

1.  **Clone this repository.**
2.  **Navigate to the root directory of the repository.**
3.  **Create or modify `terraform.tfvars` in the root directory.**  This file is where you set the values for all the variables listed above.
4.  **Initialize Terraform:** Run `terraform init` from the root directory.
5.  **Apply the Configuration:** Run `terraform apply` from the root directory. Review the plan and type `yes` to confirm.
6.  **Access Endpoints and Outputs:** After successful deployment, Terraform will output the Index Endpoint ID, Public Endpoint (if enabled), Deployed Index ID, and Index ID.
7.  **Destroy Infrastructure (When done):** Run `terraform destroy` from the root directory when you want to remove the deployed resources.

## Further Considerations

When using this Terraform code and deploying Vertex AI Vector Search, consider the following:

*   **Data Preparation and Upload:** This code assumes your embeddings and index data are already prepared and uploaded to your Cloud Storage bucket. You need to manage the data preparation pipeline separately. Ensure your data is in the correct format expected by Vertex AI Vector Search.
*   **Monitoring and Logging:** Integrate GCP Cloud Monitoring and Cloud Logging to monitor the performance and health of your Vector Search Index and Endpoint. Set up dashboards and alerts for key metrics like query latency, throughput, and resource utilization.
*   **Cost Optimization:**
    *   Carefully choose the `deployed_index_resource_type` (dedicated vs. automatic) and resource configurations based on your expected load and performance requirements. Automatic resources can be more cost-effective for variable workloads but might introduce cold starts.
    *   Monitor your resource utilization and adjust scaling parameters (`min_replicas`, `max_replicas`, `cpu_utilization_target`) to optimize costs.
    *   Consider the storage costs associated with your Cloud Storage bucket and Vertex AI Index.
*   **Index Update Methods:** This code defaults to `BATCH_UPDATE`. For near real-time updates, explore using `STREAM_UPDATE` and adjust your data ingestion pipeline accordingly.
*   **Algorithm Configuration Tuning:** The `algorithm_config` block allows you to select and configure different indexing algorithms (Tree-AH, Brute-Force). Experiment with different algorithm parameters to optimize for query speed and accuracy based on your data characteristics and performance goals.
*   **Reserved IP Ranges:** If you have specific network requirements or need to control the IP ranges used by your Deployed Index, utilize the `deployed_index_reserved_ip_ranges` variable.

By carefully considering these points and customizing the Terraform variables, you can effectively deploy and utilize Vertex AI Vector Search for your load testing framework and various other applications.