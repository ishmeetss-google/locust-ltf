"""Locust file for gRPC load testing public VVS endpoints."""

import random
import time
import uuid
import os

import google.auth
from google.cloud.aiplatform_v1 import FindNeighborsRequest, IndexDatapoint, MatchServiceClient
from google.cloud.aiplatform_v1.services.match_service.transports import grpc as match_transports_grpc
import grpc
import grpc.experimental.gevent as grpc_gevent
import locust
from locust import between, env, FastHttpUser, task, User

# patch grpc so that it uses gevent instead of asyncio
grpc_gevent.init_gevent()

# Helper function to load configuration from file
def load_config():
    config = {}
    config_path = 'config/locust_config.env'
    
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
  parser.add_argument(
      "--deployed-index-id",
      type=str,
      default="",
      help="Deployed index id for gRPC calls",
  )
  parser.add_argument(
      "--num-neighbors", type=int, default=20, help="number of neighbors"
  )
  parser.add_argument(
      "--index-endpoint-resource-name",
      type=str,
      default="",
      help=(
          """resourcename of index endpoint, required for public endpoint query requests.
          e.g. projects/1077649599081/locations/us-central1/indexEndpoints/3676832853980610560"""
      ),
  )
  parser.add_argument(
      "--index-resource-name",
      type=str,
      default=config.get('INDEX_RESOURCE_NAME'),
      help="resource name of index, required for public endpoint upsert requests.",
  )
  parser.add_argument(
      "--return-full-datapoint",
      type=bool,
      default=False,
      help="Whether to return full datapoints. Needed only for query.",
  )
  parser.add_argument(
      "--dense-embedding-num-dimensions",
      type=int,
      default=config.get('INDEX_DIMENSIONS'),
      help=(
        '''Number of dimensions for dense embedding. For dense-only embedding, 
        this dimension is the number of total dimensions. For hybrid 
        embedding, this dimension is the number of dimensions for the dense
        embedding feature vector.'''
      ),
  )
  parser.add_argument(
      "--sparse-embedding-num-dimensions",
      type=int,
      default=0,
      help=(
          "Sparse embedding max number of dimensions. Specifying a"
          "value greater than 0 to enable hybrid embedding query."
      ),
  )
  parser.add_argument(
      "--sparse-embedding-num-dimensions-with-values",
      type=int,
      default=0,
      help=(
          "Sparse embedding number of dimensions with values. Should be",
          "greater than 0 and less than or equal to",
          "sparse_embedding_num_dimensions.",
      ),
  )
  parser.add_argument(
      "--num-embeddings-per-request",
      type=int,
      default=1,
      help="Optional. Number of embeddings per request.",
    )
# class VectorSearchPublicEndpointGrpcUser(User):
#   """User that connects to Vector Search public endpoint using gRPC."""

#   wait_time = between(1, 2)

#   def __init__(self, environment: env.Environment):
#     super().__init__(environment)
#     self.vector_search_resource_name = (
#         self.environment.parsed_options.index_endpoint_resource_name
#     )
#     credentials, _ = google.auth.default()
#     request = google.auth.transport.requests.Request()
#     public_channel = google.auth.transport.grpc.secure_authorized_channel(
#         credentials,
#         request,
#         environment.host,
#         ssl_credentials=grpc.ssl_channel_credentials(),
#     )

#     self.data_client = MatchServiceClient(
#         transport=match_transports_grpc.MatchServiceGrpcTransport(
#             channel=public_channel,
#         ),
#     )

#   @task
#   def findNearestNeighbor(self):
#     request = FindNeighborsRequest(
#         index_endpoint=self.vector_search_resource_name,
#         deployed_index_id=self.environment.parsed_options.deployed_index_id,
#         return_full_datapoint=self.environment.parsed_options.return_full_datapoint,
#     )
#     dp = IndexDatapoint(
#         datapoint_id="0",
#     )
#     dp.feature_vector = [
#         random.randint(-1000000, 1000000)
#         for _ in range(
#             self.environment.parsed_options.dense_embedding_num_dimensions
#         )
#     ]

#     # hybrid embedding query
#     if (
#         self.environment.parsed_options.sparse_embedding_num_dimensions > 0
#         and self.environment.parsed_options.sparse_embedding_num_dimensions_with_values
#         > 0
#         and self.environment.parsed_options.sparse_embedding_num_dimensions_with_values
#         <= self.environment.parsed_options.sparse_embedding_num_dimensions
#     ):
#       dp.sparse_embedding = IndexDatapoint.SparseEmbedding(
#           values=[
#               random.randint(-1000000, 1000000)
#               for _ in range(
#                   self.environment.parsed_options.sparse_embedding_num_dimensions_with_values
#               )
#           ],
#           dimensions=random.sample(
#               range(
#                   self.environment.parsed_options.sparse_embedding_num_dimensions,
#               ),
#               self.environment.parsed_options.sparse_embedding_num_dimensions_with_values,
#           ),
#       )

#     query = FindNeighborsRequest.Query(
#         datapoint=dp,
#         neighbor_count=self.environment.parsed_options.num_neighbors,
#     )
#     if (
#         self.environment.parsed_options.fraction_leaf_nodes_to_search_override
#         > 0
#     ):
#       query.fraction_leaf_nodes_to_search_override = (
#           self.environment.parsed_options.fraction_leaf_nodes_to_search_override
#       )
#     request.queries.append(query)
#     start_perf_counter = time.perf_counter()
#     try:
#       response = self.data_client.find_neighbors(request)
#       self.environment.events.request.fire(
#           request_type="grpc",
#           name="MatchEngine.FindNeighbors",
#           response_time=(time.perf_counter() - start_perf_counter) * 1000,
#           response=response,
#           response_length=0,
#       )
#     except Exception as e:
#       self.environment.events.request.fire(
#           request_type="grpc",
#           name="MatchEngine.FindNeighbors",
#           response_time=(time.perf_counter() - start_perf_counter) * 1000,
#           response_length=0,
#           exception=e,
#       )



class VectorSearchPublicUpsertFastHTTPUser(FastHttpUser):
  """User that upserts datapoints to Vertex Vector Search Index."""

  wait_time = locust.between(1, 2)
  host = f'https://{config.get("ENDPOINT_HOST")}'

  def __init__(self, environment: locust.env.Environment):
    super().__init__(environment)
    self.index_url = (
        "/v1/"
        + self.environment.parsed_options.index_resource_name
        + ":upsertDatapoints"
    )
    self.credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    self.auth_req = google.auth.transport.requests.Request()
    self.credentials.refresh(self.auth_req)
    self.headers = {
        "Authorization": "Bearer " + self.credentials.token,
        "Content-Type": "application/json",
    }

  @locust.task
  def upsertDatapoints(self):
    dps = {"datapoints": []}
    for _ in range(self.environment.parsed_options.num_embeddings_per_request):
      dp = {"datapointId": str(uuid.uuid4())}
      dp["featureVector"] = [
          random.random()
          for _ in range(
              self.environment.parsed_options.dense_embedding_num_dimensions
          )
      ]
      # hybrid embedding query
      if (
          self.environment.parsed_options.sparse_embedding_num_dimensions > 0
          and self.environment.parsed_options.sparse_embedding_num_dimensions_with_values
          > 0
          and self.environment.parsed_options.sparse_embedding_num_dimensions_with_values
          <= self.environment.parsed_options.sparse_embedding_num_dimensions
      ):
        dp["sparseEmbedding"] = {}
        dp["sparseEmbedding"]["values"] = []
        for _ in range(
            self.environment.parsed_options.sparse_embedding_num_dimensions_with_values
        ):
          dp["sparseEmbedding"]["values"].append(random.uniform(-1, 1))
        dp["sparseEmbedding"]["dimensions"] = random.sample(
            range(
                self.environment.parsed_options.sparse_embedding_num_dimensions,
            ),
            self.environment.parsed_options.sparse_embedding_num_dimensions_with_values,
        )
      dps["datapoints"].append(dp)

    with self.client.request(
        "POST",
        url=self.index_url,
        json=dps,
        catch_response=True,
        headers=self.headers,
    ) as response:
      if response.status_code == 401:
        self.credentials.refresh(self.auth_req)
        self.headers["Authorization"] = "Bearer " + self.credentials.token