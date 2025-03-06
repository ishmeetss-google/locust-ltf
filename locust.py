"""Locust file for load testing Vector Search endpoints (both public HTTP and private PSC/gRPC)."""

import random
import os
import time

import google.auth
import google.auth.transport.requests
from google.cloud.aiplatform_v1 import MatchServiceClient
from google.cloud.aiplatform_v1 import FindNeighborsRequest
from google.cloud.aiplatform_v1 import IndexDatapoint
from google.cloud.aiplatform_v1.services.match_service.transports import grpc as match_transports_grpc
import grpc
import grpc.experimental.gevent as grpc_gevent
import locust
from locust import between, env, FastHttpUser, User, task, events, wait_time

# Patch grpc so that it uses gevent instead of asyncio
grpc_gevent.init_gevent()

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
        'PROJECT_ID': '',
        'PSC_ENABLED': 'false',
        'MATCH_GRPC_ADDRESS': '',
        'SERVICE_ATTACHMENT': ''
    }
    
    for key, default in defaults.items():
        if key not in config:
            config[key] = default
    
    return config

# Load configuration
config = load_config()
print(f"Loaded configuration: PSC_ENABLED={config.get('PSC_ENABLED', 'false')}")

@events.init_command_line_parser.add_listener
def _(parser):
    """Add command line arguments to the Locust environment."""
    # Add user-focused test parameters
    parser.add_argument(
        "--num-neighbors", 
        type=int, 
        default=20, 
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
    
    # Advanced parameters
    parser.add_argument(
        "--fraction-leaf-nodes-to-search-override",
        type=float,
        default=0.0,
        help="Advanced: Fraction of leaf nodes to search (0.0-1.0). Higher values increase recall but reduce performance."
    )


class VectorSearchHttpUser(FastHttpUser):
    """User that connects to Vector Search public endpoint using HTTP."""
    
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
        
        # Set the host from config
        self.host = f'https://{config.get("ENDPOINT_HOST")}'
        
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
        }
        
        dp = {
            "datapointId": "0",
        }
        query = {
            "datapoint": dp,
            "neighborCount": environment.parsed_options.num_neighbors,
        }
        
        # Add optional parameters if specified
        if environment.parsed_options.fraction_leaf_nodes_to_search_override > 0:
            query["fractionLeafNodesToSearchOverride"] = environment.parsed_options.fraction_leaf_nodes_to_search_override
            
        self.request["queries"] = [query]

    @task
    def findNearestNeighbors(self):
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


class VectorSearchGrpcUser(User):
    """User that connects to Vector Search private endpoint using gRPC over PSC."""
    
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
        
        # Get the gRPC address from the config
        self.match_grpc_address = config.get('MATCH_GRPC_ADDRESS', '')
        if not self.match_grpc_address:
            raise ValueError("MATCH_GRPC_ADDRESS must be provided for PSC/gRPC connections")
            
        # Create a gRPC channel and client
        channel = self._create_grpc_channel(self.match_grpc_address)
        self.client = MatchServiceClient(
            transport=match_transports_grpc.MatchServiceGrpcTransport(
                channel=channel
            )
        )
        
        # Store parsed options needed for requests
        self.num_neighbors = environment.parsed_options.num_neighbors
        self.fraction_leaf_nodes_to_search_override = environment.parsed_options.fraction_leaf_nodes_to_search_override

    def _create_grpc_channel(self, address):
        """Create a gRPC channel for PSC communication."""
        # For PSC, we don't need SSL or auth credentials
        # The channel connects directly to the private endpoint
        return grpc.insecure_channel(address)

    @task
    def findNearestNeighbors(self):
        """Execute a Vector Search query with random vector using gRPC."""
        # Create a datapoint for the request
        datapoint = IndexDatapoint(
            datapoint_id="0",
            feature_vector=[
                random.randint(-1000000, 1000000)
                for _ in range(self.dimensions)
            ]
        )
        
        # Create a query
        query = FindNeighborsRequest.Query(
            datapoint=datapoint,
            neighbor_count=self.num_neighbors
        )
        
        # Add optional parameters if specified
        if self.fraction_leaf_nodes_to_search_override > 0:
            query.fraction_leaf_nodes_to_search_override = self.fraction_leaf_nodes_to_search_override
        
        # Create the request
        request = FindNeighborsRequest(
            index_endpoint=self.index_endpoint_id,
            deployed_index_id=self.deployed_index_id,
            queries=[query]
        )
        
        # Send the request and measure the performance
        start_time = time.perf_counter()
        try:
            response = self.client.find_neighbors(request)
            response_time = (time.perf_counter() - start_time) * 1000
            
            # Log the response to Locust
            self.environment.events.request.fire(
                request_type="grpc",
                name="MatchService.FindNeighbors",
                response_time=response_time,
                response_length=0,  # We don't track the response size for now
                exception=None
            )
        except Exception as e:
            response_time = (time.perf_counter() - start_time) * 1000
            
            # Log the error to Locust
            self.environment.events.request.fire(
                request_type="grpc",
                name="MatchService.FindNeighbors",
                response_time=response_time,
                response_length=0,
                exception=e
            )


# Determine which user class to use based on configuration
UserClass = VectorSearchGrpcUser if config.get('PSC_ENABLED', 'false').lower() in ('true', 'yes', '1') else VectorSearchHttpUser