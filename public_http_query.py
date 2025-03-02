"""Locust file for http load testing public VVS endpoints."""

import random
import os

import google.auth
import google.auth.transport.requests
import locust
from locust import between
from locust import env
from locust import FastHttpUser
from locust import task

# Helper function to load configuration from file
def load_config():
    config = {}
    config_path = '/tasks/locust_config.env'
    
    if os.path.exists(config_path):
        with open(config_path, 'r') as f:
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    config[key] = value
    
    # Set default values if not in config
    defaults = {
        'INDEX_DIMENSIONS': '768',
        'DEPLOYED_INDEX_ID': '',
        'INDEX_ENDPOINT_ID': '',
        'ENDPOINT_HOST': '',
        'PROJECT_ID': ''
    }
    
    for key, default in defaults.items():
        if key not in config:
            config[key] = default
    
    return config

# Load configuration
config = load_config()

@locust.events.init_command_line_parser.add_listener
def _(parser):
    """Add command line arguments to the Locust environment.

    Args:
      parser: parser to add arguments
    """
    parser.add_argument(
        "--deployed-index-id",
        type=str,
        default=config.get('DEPLOYED_INDEX_ID', ""),
        help="Deployed index id for http calls",
    )
    parser.add_argument(
        "--num-neighbors", type=int, default=20, help="number of neighbors"
    )
    parser.add_argument(
        "--num-dimensions", 
        type=int, 
        default=int(config.get('INDEX_DIMENSIONS', 768)), 
        help="number of dimensions"
    )
    parser.add_argument(
        "--index-endpoint-resource-name",
        type=str,
        default=config.get('INDEX_ENDPOINT_ID', ""),
        help="full name of index endpoint.",
    )
    parser.add_argument(
        "--fraction-leaf-nodes-to-search-override",
        type=float,
        default=0.0,
        help="fraction leaf nodes to search override at query time.",
    )
    parser.add_argument(
        "--return-full-datapoint",
        type=bool,
        default=False,
        help="Whether to return full datapoints. Needed only for query.",
    )
    parser.add_argument(
        "--host",
        type=str,
        default=f"https://{config.get('ENDPOINT_HOST', '')}",
        help="Vector Search endpoint host",
    )
    parser.add_argument(
        "--project-id",
        type=str,
        default=config.get('PROJECT_ID', ""),
        help="GCP Project ID",
    )


class VectorSearchPublicEndpointHttpUser(FastHttpUser):
    """User that connects to Vector Search public endpoint using http."""
    wait_time = between(1, 2)
    
    def __init__(self, environment: env.Environment):
        super().__init__(environment)
        # Use host from command line or environment config
        self.host = environment.host or f"https://{config.get('ENDPOINT_HOST', '')}"
        
        self.credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        self.auth_req = google.auth.transport.requests.Request()
        self.credentials.refresh(self.auth_req)
        self.headers = {
            "Authorization": "Bearer " + self.credentials.token,
            "Content-Type": "application/json",
        }
        self.public_endpoint_url = (
            "/v1/"
            + self.environment.parsed_options.index_endpoint_resource_name
            + ":findNeighbors"
        )
        self.request = {
            "deployedIndexId": self.environment.parsed_options.deployed_index_id,
            "returnFullDatapoint": (
                self.environment.parsed_options.return_full_datapoint
            ),
        }
        dp = {
            "datapointId": "0",
        }
        query = {
            "datapoint": dp,
            "neighborCount": self.environment.parsed_options.num_neighbors,
        }
        self.request["queries"] = [query]

    @task
    def findNearestNeighbor(self):
        self.request["queries"][0]["datapoint"]["featureVector"] = [
            random.randint(-1000000, 1000000)
            for _ in range(self.environment.parsed_options.num_dimensions)
        ]
        with self.client.request(
            "POST",
            url=self.public_endpoint_url,
            json=self.request,
            catch_response=True,
            headers=self.headers,
        ) as response:
            if response.status_code == 401:
                self.credentials.refresh(self.auth_req)
                self.headers["Authorization"] = (
                    "Bearer " + self.credentials.token
                )