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
from locust import wait_time

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
    else:
        print("Warning: Config file not found at", config_path)
    
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
    # Add user-focused test parameters
    parser.add_argument(
        "--num-neighbors", 
        type=int, 
        default=20, 
        help="Number of nearest neighbors to find in each query"
    )
    
    # parser.add_argument(
    #     "--return-full-datapoint",
    #     type=bool,
    #     default=False,
    #     help="Whether to return full datapoints. Increases response size."
    # )
    
    # Add QPS per user control
    parser.add_argument(
        "--qps-per-user",
        type=int,
        default=10,
        help=(
            'The QPS each user should target. Locust will try to maintain this rate, '
            'but if latency is high, actual QPS may be lower.'
        ),
    )
     
    # # Add advanced parameters
    # parser.add_argument(
    #     "--fraction-leaf-nodes-to-search-override",
    #     type=float,
    #     default=0.0,
    #     help="Advanced: Fraction of leaf nodes to search (0.0-1.0). Higher values increase recall but reduce performance."
    # )




class VectorSearchPublicEndpointHttpUser(FastHttpUser):
    """User that connects to Vector Search public endpoint using http."""
    # Default wait time between requests - will be overridden if qps-per-user is set
    host = f'https://{config.get("ENDPOINT_HOST")}'

    def __init__(self, environment: env.Environment):
        # Set up QPS-based wait time if specified
        user_qps = environment.parsed_options.qps_per_user
        if user_qps > 0:
            # Use constant throughput based on QPS setting
            def wait_time_fn():
                fn = wait_time.constant_throughput(user_qps)
                return fn(self)
            self.wait_time = wait_time_fn
            
        # Call parent initialization
        super().__init__(environment)
        
        # Read technical parameters from config file
        self.deployed_index_id = config.get('DEPLOYED_INDEX_ID')
        self.index_endpoint_id = config.get('INDEX_ENDPOINT_ID')
        self.project_id = config.get('PROJECT_ID')
        self.dimensions = int(config.get('INDEX_DIMENSIONS', 768))
        
        # Set up authentication
        self.credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        self.auth_req = google.auth.transport.requests.Request()
        self.credentials.refresh(self.auth_req)
        self.headers = {
            "Authorization": "Bearer " + self.credentials.token,
            "Content-Type": "application/json",
        }
        
        # Build the endpoint URL
        self.public_endpoint_url = f"/v1/{self.index_endpoint_id}:findNeighbors"
        
        # Build the base request
        self.request = {
            "deployedIndexId": self.deployed_index_id,
            # "returnFullDatapoint": environment.parsed_options.return_full_datapoint,
        }
        
        dp = {
            "datapointId": "0",
        }
        query = {
            "datapoint": dp,
            "neighborCount": environment.parsed_options.num_neighbors,
        }
        self.request["queries"] = [query]
        
        # Add optional parameters if specified
        # if environment.parsed_options.fraction_leaf_nodes_to_search_override > 0:
            # self.request["fractionLeafNodesToSearchOverride"] = environment.parsed_options.fraction_leaf_nodes_to_search_override

    @task
    def findNearestNeighbor(self):
        """Execute a Vector Search query with random vector."""
        # Generate a random vector of the right dimensionality
        self.request["queries"][0]["datapoint"]["featureVector"] = [
            random.randint(-1000000, 1000000)
            for _ in range(self.dimensions)
        ]
        
        # Send the request and handle the response
        with self.client.request(
            "POST",
            url=self.public_endpoint_url,
            json=self.request,
            catch_response=True,
            headers=self.headers,
        ) as response:
            if response.status_code == 401:
                # Refresh token on auth error
                self.credentials.refresh(self.auth_req)
                self.headers["Authorization"] = "Bearer " + self.credentials.token
            elif response.status_code != 200:
                # Mark failed responses
                response.failure(f"Failed with status code: {response.status_code}, body: {response.text}")