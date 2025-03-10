"""Locust file for load testing Vector Search endpoints (both public HTTP and private PSC/gRPC)."""

import random
import os
import time
from typing import Any, Callable

import google.auth
import google.auth.transport.requests
import google.auth.transport.grpc
from google.cloud.aiplatform_v1 import MatchServiceClient
from google.cloud.aiplatform_v1 import FindNeighborsRequest
from google.cloud.aiplatform_v1 import IndexDatapoint
from google.cloud.aiplatform_v1.services.match_service.transports import grpc as match_transports_grpc
import grpc
import grpc.experimental.gevent as grpc_gevent
import grpc_interceptor
import locust
from locust import between, env, FastHttpUser, User, task, events, wait_time, tag
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')

# Patch grpc so that it uses gevent instead of asyncio
grpc_gevent.init_gevent()

# gRPC channel cache
_GRPC_CHANNEL_CACHE = {}

class LocustInterceptor(grpc_interceptor.ClientInterceptor):
    """Interceptor for Locust which captures response details."""

    def __init__(self, environment, *args, **kwargs):
        """Initializes the interceptor with the specified environment."""
        super().__init__(*args, **kwargs)
        self.env = environment

    def intercept(
        self,
        method: Callable[[Any, grpc.ClientCallDetails], Any],
        request_or_iterator: Any,
        call_details: grpc.ClientCallDetails,
    ) -> Any:
        """Intercepts message to store RPC latency and response size."""
        response = None
        exception = None
        end_perf_counter = None
        response_length = 0
        start_perf_counter = time.perf_counter()
        try:
            # Response type
            #  * Unary: `grpc._interceptor._UnaryOutcome`
            #  * Streaming: `grpc._channel._MultiThreadedRendezvous`
            response_or_responses = method(request_or_iterator, call_details)
            end_perf_counter = time.perf_counter()

            if isinstance(response_or_responses, grpc._channel._Rendezvous):
                responses = list(response_or_responses)
                # Re-write perf counter to account for time taken to receive all messages.
                end_perf_counter = time.perf_counter()

                # Total length = sum(messages).
                total_length = 0
                for message in responses:
                    message_pb = message.__class__.pb(message)
                    response_length = message_pb.ByteSize()
                    total_length += response_length

                # Re-write response to return the actual responses since above logic has
                # consumed all responses.
                def yield_responses():
                    for rsp in responses:
                        yield rsp

                response_or_responses = yield_responses()
            else:
                response = response_or_responses
                # Unary
                message = response.result()
                message_pb = message.__class__.pb(message)
                response_length = message_pb.ByteSize()
        except grpc.RpcError as e:
            exception = e
            end_perf_counter = time.perf_counter()

        self.env.events.request.fire(
            request_type='grpc',
            name=call_details.method,
            response_time=(end_perf_counter - start_perf_counter) * 1000,
            response_length=response_length,
            response=response_or_responses,
            context=None,
            exception=exception,
        )
        return response_or_responses


def _create_grpc_auth_channel(host: str) -> grpc.Channel:
    """Create a gRPC channel with SSL and auth."""
    credentials, _ = google.auth.default()
    request = google.auth.transport.requests.Request()
    CHANNEL_OPTIONS = [
        ('grpc.use_local_subchannel_pool', True),
    ]
    return google.auth.transport.grpc.secure_authorized_channel(
        credentials,
        request,
        host,
        ssl_credentials=grpc.ssl_channel_credentials(),
        options=CHANNEL_OPTIONS,
    )


def _cached_grpc_channel(
    host: str, auth: bool, cache: bool = True
) -> grpc.Channel:
    """Return a cached gRPC channel for the given host and auth type."""
    key = (host, auth)
    if cache and key in _GRPC_CHANNEL_CACHE:
        return _GRPC_CHANNEL_CACHE[key]

    new_channel = (
        _create_grpc_auth_channel(host) if auth else grpc.insecure_channel(host)
    )
    if not cache:
        return new_channel

    _GRPC_CHANNEL_CACHE[key] = new_channel
    return _GRPC_CHANNEL_CACHE[key]


def intercepted_cached_grpc_channel(
    host: str,
    auth: bool,
    env: locust.env.Environment,
    cache: bool = True,
) -> grpc.Channel:
    """Return a intercepted gRPC channel for the given host and auth type."""
    channel = _cached_grpc_channel(host, auth=auth, cache=cache)
    interceptor = LocustInterceptor(environment=env)
    return grpc.intercept_channel(channel, interceptor)

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
        logging.info(f"Loaded configuration from {config_path}")
    else:
        logging.warning(f"Warning: Config file not found at {config_path}")
    
    # Set default values if not in config
    defaults = {
        'INDEX_DIMENSIONS': '768',
        'DEPLOYED_INDEX_ID': '',
        'INDEX_ENDPOINT_ID': '',
        'ENDPOINT_HOST': '',
        'PROJECT_ID': '',
        'PSC_ENABLED': 'false',
        'MATCH_GRPC_ADDRESS': '',
        'SERVICE_ATTACHMENT': '',
        'PSC_IP_ADDRESS': ''
    }
    
    for key, default in defaults.items():
        if key not in config:
            config[key] = default
            
    # If we have PSC_IP_ADDRESS but not MATCH_GRPC_ADDRESS, construct it
    if config.get('PSC_IP_ADDRESS') and not config.get('MATCH_GRPC_ADDRESS'):
        config['MATCH_GRPC_ADDRESS'] = f"{config['PSC_IP_ADDRESS']}:10000"
        
    return config

# Load configuration
config = load_config()
logging.info(f"Loaded configuration: PSC_ENABLED={config.get('PSC_ENABLED', 'false')}, "
      f"MATCH_GRPC_ADDRESS={config.get('MATCH_GRPC_ADDRESS', '')}, "
      f"ENDPOINT_HOST={config.get('ENDPOINT_HOST', '')}")

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
    
    # Add auto-host flag
    parser.add_argument(
        "--auto-host",
        action="store_true",
        default=True,
        help="Automatically set host based on PSC configuration"
    )

@events.init.add_listener
def on_locust_init(environment, **kwargs):
    """Set up the host and tags based on configuration."""
    is_psc_enabled = config.get('PSC_ENABLED', 'false').lower() in ('true', 'yes', '1')
    
    # Set default tags based on PSC mode if no tags were specified
    if hasattr(environment.parsed_options, 'tags') and not environment.parsed_options.tags:
        if is_psc_enabled:
            environment.parsed_options.tags = ['grpc']
            logging.info("Auto-setting tags to 'grpc' based on PSC configuration")
        else:
            environment.parsed_options.tags = ['http']
            logging.info("Auto-setting tags to 'http' based on PSC configuration")
    
    # Set host based on PSC mode if no host was specified
    if not environment.host:
        if is_psc_enabled:
            # PSC/gRPC mode
            grpc_address = config.get('MATCH_GRPC_ADDRESS', '')
            if grpc_address:
                logging.info(f"Auto-setting host to gRPC address: {grpc_address}")
                environment.host = grpc_address
        else:
            # HTTP mode
            endpoint_host = config.get('ENDPOINT_HOST', '')
            if endpoint_host:
                host = f"https://{endpoint_host}"
                logging.info(f"Auto-setting host to HTTP endpoint: {host}")
                environment.host = host

class VectorSearchUser(User):
    """Combined Vector Search user class with both HTTP and gRPC implementations."""
    
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
        
        # Determine which mode we're running in based on PSC_ENABLED
        self.use_psc = config.get('PSC_ENABLED', 'false').lower() in ('true', 'yes', '1')
        
        # Setup HTTP client if needed
        if not self.use_psc or 'http' in getattr(self.environment.parsed_options, 'tags', []):
            # Set up HTTP authentication
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
            logging.info("HTTP client initialized")
        
        # Setup gRPC client if needed
        if self.use_psc or 'grpc' in getattr(self.environment.parsed_options, 'tags', []):
            # Get the PSC address from the config
            self.match_grpc_address = config.get('MATCH_GRPC_ADDRESS', '')
            
            # Validate configuration
            if not self.match_grpc_address:
                raise ValueError("MATCH_GRPC_ADDRESS must be provided for PSC/gRPC connections")
            
            logging.info(f"Using PSC/gRPC address: {self.match_grpc_address}")
                
            # Create a gRPC channel with interceptor
            channel = intercepted_cached_grpc_channel(
                self.match_grpc_address,  # Using match_grpc_address directly
                auth=False,  # PSC connections don't need auth
                env=environment
            )
            
            # Create the client
            self.grpc_client = MatchServiceClient(
                transport=match_transports_grpc.MatchServiceGrpcTransport(
                    channel=channel
                )
            )
            logging.info("gRPC client initialized")
        
        # Store parsed options needed for requests
        self.num_neighbors = environment.parsed_options.num_neighbors
        self.fraction_leaf_nodes_to_search_override = environment.parsed_options.fraction_leaf_nodes_to_search_override

    @task
    @tag('http')
    def http_find_neighbors(self):
        """Execute a Vector Search query using HTTP."""
        if not hasattr(self, 'request'):
            return  # Skip if not in HTTP mode
            
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
    
    @task
    @tag('grpc')
    def grpc_find_neighbors(self):
        """Execute a Vector Search query using gRPC."""
        if not hasattr(self, 'grpc_client'):
            return  # Skip if not in gRPC mode
            
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
        
        # The interceptor will handle performance metrics automatically
        try:
            response = self.grpc_client.find_neighbors(request)
        except Exception as e:
            logging.error(f"Error in gRPC call: {str(e)}")
            raise  # The interceptor will handle the error reporting