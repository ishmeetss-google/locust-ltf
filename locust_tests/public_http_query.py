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
    # config_path = 'config/locust_config.env'
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
        'PROJECT_ID': '',
        'SPARSE_EMBEDDING_NUM_DIMENSIONS': '0',
        'SPARSE_EMBEDDING_NUM_DIMENSIONS_WITH_VALUES': '0',
        'NUM_NEIGHBORS': '20',
        'NUM_EMBEDDINGS_PER_REQUEST': '1',
        'RETURN_FULL_DATAPOINT': 'False'
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
        default=int(config.get('NUM_NEIGHBORS', 20)), 
        help="Number of nearest neighbors to find in each query"
    )
    
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
    
    # Add return full datapoint option
    parser.add_argument(
        "--return-full-datapoint",
        action="store_true",
        default=config.get('RETURN_FULL_DATAPOINT', 'False').lower() in ('true', 'yes', '1'),
        help="Whether to return the full datapoint in the response"
    )

class VectorSearchData:
    def __init__(self):
        self.deployed_index_id = config.get('DEPLOYED_INDEX_ID')
        self.index_endpoint_id = config.get('INDEX_ENDPOINT_ID')
        self.project_id = config.get('PROJECT_ID')
        self.dimensions = int(config.get('INDEX_DIMENSIONS', 768))
        self.sparse_embedding_num_dimensions = int(config.get('SPARSE_EMBEDDING_NUM_DIMENSIONS', 0))
        self.sparse_embedding_num_dimensions_with_values = int(config.get('SPARSE_EMBEDDING_NUM_DIMENSIONS_WITH_VALUES', 0))
        self.num_neighbors = int(config.get('NUM_NEIGHBORS', 20)) 
        self.num_embeddings_per_request = int(config.get('NUM_EMBEDDINGS_PER_REQUEST', 1))
        self.return_full_datapoint = config.get('RETURN_FULL_DATAPOINT', 'False').lower() in ('true', 'yes', '1')
     
class VectorSearchSingle(FastHttpUser):
    """User that connects to Vector Search public endpoint using http."""
    # Default wait time between requests - will be overridden if qps-per-user is set
    host = f'https://{config.get("ENDPOINT_HOST")}'

    def __init__(self, environment: env.Environment):
        super().__init__(environment)
        
        # Set host from config
        self.host = f'https://{config.get("ENDPOINT_HOST")}'
        
        # Load vector search data
        self.vs_data = VectorSearchData()
        
        # Set up QPS-based wait time if specified
        user_qps = environment.parsed_options.qps_per_user
        if user_qps > 0:
            # Use constant throughput based on QPS setting
            def wait_time_fn():
                fn = wait_time.constant_throughput(user_qps)
                return fn(self)
            self.wait_time = wait_time_fn
            
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
        self.public_endpoint_url = f"/v1/{self.vs_data.index_endpoint_id}:findNeighbors"
        
        # Get num_neighbors from command line or config
        self.num_neighbors = getattr(environment.parsed_options, 'num_neighbors', self.vs_data.num_neighbors)
        
        # Build the base request
        self.request = {
            "deployedIndexId": self.vs_data.deployed_index_id,
            "returnFullDatapoint": getattr(environment.parsed_options, 'return_full_datapoint', self.vs_data.return_full_datapoint),
        }
        
        dp = {
            "datapointId": "0",
        }
        query = {
            "datapoint": dp,
            "neighborCount": self.num_neighbors,
        }
        self.request["queries"] = [query]

    @task
    def findNearestNeighbor(self):
        """Execute a Vector Search query with random vector."""
        # Generate a random vector of the right dimensionality
        self.request["queries"][0]["datapoint"]["featureVector"] = [
            random.randint(-1000000, 1000000)
            for _ in range(self.vs_data.dimensions)
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

class VectorSearchBlended(FastHttpUser):
    """User that executes blended (hybrid) vector search queries."""
    wait_time = between(1, 2)
    host = f'https://{config.get("ENDPOINT_HOST")}'
   
    def __init__(self, environment: locust.env.Environment):
        super().__init__(environment)
        
        # Set host from config
        self.host = f'https://{config.get("ENDPOINT_HOST")}'
        
        # Load vector search data
        self.vs_data = VectorSearchData()
        
        # Set up QPS-based wait time if specified
        user_qps = getattr(environment.parsed_options, 'qps_per_user', 0)
        if user_qps > 0:
            # Use constant throughput based on QPS setting
            def wait_time_fn():
                fn = wait_time.constant_throughput(user_qps)
                return fn(self)
            self.wait_time = wait_time_fn
        
        # Set the endpoint URL
        self.public_endpoint_url = f"/v1/{self.vs_data.index_endpoint_id}:findNeighbors"
        
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
        
        # Get return_full_datapoint from command line or config
        self.return_full_datapoint = getattr(environment.parsed_options, 'return_full_datapoint', self.vs_data.return_full_datapoint)

    @task
    def findNeighbors(self):
        """Execute a blended Vector Search query with random vectors."""
        json_request = {
            "deployedIndexId": self.vs_data.deployed_index_id,
            "returnFullDatapoint": self.return_full_datapoint,
            "queries": [],
        }
        
        for _ in range(self.vs_data.num_embeddings_per_request):
            datapoint = {"datapointId": "0"}
            
            # Generate dense embedding
            datapoint["featureVector"] = [
                random.random() for _ in range(self.vs_data.dimensions)
            ]
            
            # Add sparse embedding if configured
            if (self.vs_data.sparse_embedding_num_dimensions > 0 and 
                self.vs_data.sparse_embedding_num_dimensions_with_values > 0 and
                self.vs_data.sparse_embedding_num_dimensions_with_values <= self.vs_data.sparse_embedding_num_dimensions):
                
                dimensions = random.sample(
                    range(self.vs_data.sparse_embedding_num_dimensions),
                    self.vs_data.sparse_embedding_num_dimensions_with_values
                )
                
                values = [random.uniform(-1, 1) 
                          for _ in range(self.vs_data.sparse_embedding_num_dimensions_with_values)]
                
                datapoint["sparseEmbedding"] = {
                    "dimensions": dimensions,
                    "values": values
                }
            
            json_request["queries"].append({"datapoint": datapoint})

        with self.client.request(
            "POST",
            url=self.public_endpoint_url,
            json=json_request,
            catch_response=True,
            headers=self.headers,
        ) as response:
            if response.status_code == 401:
                self.credentials.refresh(self.auth_req)
                self.headers["Authorization"] = "Bearer " + self.credentials.token
            elif response.status_code != 200:
                response.failure(f"Failed with status code: {response.status_code}, body: {response.text}")