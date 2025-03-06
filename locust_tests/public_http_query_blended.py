"""Locust file for http load testing Vector Search endpoints with blended search."""

import random
import os
import json
import time

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
        'INDEX_DIMENSIONS': '768',     # Dense vector dimensions
        'SPARSE_DIMENSIONS': '5000',   # Sparse vector dimensions
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
    """Add command line arguments to the Locust environment."""
    # Add user-focused test parameters
    parser.add_argument(
        "--num-neighbors", 
        type=int, 
        default=20, 
        help="Number of nearest neighbors to find in each query"
    )
    
    parser.add_argument(
        "--return-full-datapoint",
        action="store_true",
        default=False,
        help="Whether to return full datapoints. Increases response size."
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
    
    # Add sparse search parameters
    parser.add_argument(
        "--sparse-values-count",
        type=int,
        default=10,
        help="Number of non-zero values in sparse vectors"
    )
    
    # Add hybrid parameter
    parser.add_argument(
        "--hybrid-alpha",
        type=float,
        default=0.5,
        help="Alpha parameter for hybrid search (0.0-1.0). Higher values favor dense search."
    )
    
    # Add advanced parameters
    parser.add_argument(
        "--fraction-leaf-nodes-to-search-override",
        type=float,
        default=0.0,
        help="Advanced: Fraction of leaf nodes to search (0.0-1.0). Higher values increase recall but reduce performance."
    )
    
    parser.add_argument(
        "--debug-mode",
        action="store_true",
        default=False,
        help="Enable debug output"
    )


class VectorSearchBlendedUser(FastHttpUser):
    """User that performs blended vector searches with both dense and sparse vectors."""
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
        
        # Debug mode
        self.debug_mode = environment.parsed_options.debug_mode
        
        # Read technical parameters from config file
        self.deployed_index_id = config.get('DEPLOYED_INDEX_ID')
        self.index_endpoint_id = config.get('INDEX_ENDPOINT_ID')
        self.project_id = config.get('PROJECT_ID')
        self.dense_dimensions = int(config.get('INDEX_DIMENSIONS', 768))
        self.sparse_dimensions = int(config.get('SPARSE_DIMENSIONS', 5000))
        self.sparse_values_count = environment.parsed_options.sparse_values_count
        self.hybrid_alpha = environment.parsed_options.hybrid_alpha
        
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
        
        # Log configuration in debug mode
        if self.debug_mode:
            self._log_config()
    
    def _log_config(self):
        """Log configuration for debugging."""
        print("\n=== Blended Vector Search Configuration ===")
        print(f"Host: {self.host}")
        print(f"Endpoint URL: {self.public_endpoint_url}")
        print(f"Deployed Index ID: {self.deployed_index_id}")
        print(f"Dense Dimensions: {self.dense_dimensions}")
        print(f"Sparse Dimensions: {self.sparse_dimensions}")
        print(f"Sparse Values Count: {self.sparse_values_count}")
        print(f"Hybrid Alpha: {self.hybrid_alpha}")
        print(f"QPS per User: {self.environment.parsed_options.qps_per_user}")
        print(f"Num Neighbors: {self.environment.parsed_options.num_neighbors}")
        print(f"Return Full Datapoint: {self.environment.parsed_options.return_full_datapoint}")
        print("=====================================\n")

    @task
    def blended_search(self):
        """Execute a blended Vector Search query with both dense and sparse vectors."""
        # Create the request
        request = {
            "deployedIndexId": self.deployed_index_id,
            "returnFullDatapoint": self.environment.parsed_options.return_full_datapoint,
            "queries": []
        }
        
        # Generate a random dense vector
        dense_vector = [
            random.uniform(-1.0, 1.0)
            for _ in range(self.dense_dimensions)
        ]
        
        # Randomly select dimensions and values for sparse embedding
        sparse_dimensions = sorted(random.sample(
            range(self.sparse_dimensions), 
            self.sparse_values_count
        ))
        
        sparse_values = [
            random.uniform(0.1, 1.0) 
            for _ in range(self.sparse_values_count)
        ]
        
        # Create datapoint with both vectors
        dp = {
            "datapointId": "0",
            "featureVector": dense_vector,
            "sparseVector": {
                "dimensions": sparse_dimensions,
                "values": sparse_values
            }
        }
        
        # Create query with RRF alpha parameter
        query = {
            "datapoint": dp,
            "neighborCount": self.environment.parsed_options.num_neighbors,
            "rrf": {
                "alpha": self.hybrid_alpha
            }
        }
        
        # Add to request
        request["queries"].append(query)
        
        # Add fraction leaf nodes parameter if specified
        leaf_override = self.environment.parsed_options.fraction_leaf_nodes_to_search_override
        if leaf_override > 0:
            request["fractionLeafNodesToSearchOverride"] = leaf_override
        
        # Debug output
        if self.debug_mode:
            sparse_info = {
                "dimensions_count": len(sparse_dimensions),
                "sample_dimensions": sparse_dimensions[:3] if len(sparse_dimensions) > 3 else sparse_dimensions,
                "sample_values": sparse_values[:3] if len(sparse_values) > 3 else sparse_values
            }
            print(f"Sending blended search with alpha: {self.hybrid_alpha}, sparse info: {json.dumps(sparse_info)}")
        
        # Send the request
        with self.client.request(
            "POST",
            url=self.public_endpoint_url,
            json=request,
            catch_response=True,
            headers=self.headers,
        ) as response:
            
            if response.status_code == 401:
                # Refresh token on auth error
                response.failure("Authentication failed (401)")
                self.credentials.refresh(self.auth_req)
                self.headers["Authorization"] = "Bearer " + self.credentials.token
                if self.debug_mode:
                    print("Auth error (401), token refreshed")
            
            elif response.status_code == 404:
                response.failure(f"Endpoint not found (404): {response.text}")
                if self.debug_mode:
                    print(f"Endpoint not found: {self.public_endpoint_url}")
                    print("Check your INDEX_ENDPOINT_ID configuration")
            
            elif response.status_code == 400:
                response.failure(f"Bad request (400): {response.text}")
                if self.debug_mode:
                    print(f"Bad request error: {response.text}")
                    print("This may indicate an issue with the request format or sparse vector implementation")
            
            elif response.status_code != 200:
                # Mark other failed responses
                response.failure(f"Failed with status code: {response.status_code}, body: {response.text}")
                if self.debug_mode:
                    print(f"Error: {response.status_code} - {response.text}")
            
            else:
                # Success case
                response.success()
                if self.debug_mode:
                    try:
                        result = json.loads(response.text)
                        neighbors = result.get("nearestNeighbors", [{}])[0].get("neighbors", [])
                        neighbor_count = len(neighbors)
                        
                        # Show some result details
                        if neighbor_count > 0 and self.debug_mode:
                            sample_neighbors = neighbors[:2] if neighbor_count > 2 else neighbors
                            print(f"Found {neighbor_count} neighbors in {response_time:.2f}ms")
                            for i, neighbor in enumerate(sample_neighbors):
                                print(f"  Neighbor {i+1}: ID={neighbor.get('id', 'unknown')}, " +
                                      f"Distance={neighbor.get('distance', 'unknown')}")
                    except:
                        print(f"Query successful in {response_time:.2f}ms but couldn't parse response")