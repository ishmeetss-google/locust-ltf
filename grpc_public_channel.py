"""Locust file for gRPC load testing public VVS endpoints."""

import random
import time
import uuid

import google.auth
from google.cloud.aiplatform_v1 import FindNeighborsRequest
from google.cloud.aiplatform_v1 import IndexDatapoint
from google.cloud.aiplatform_v1 import MatchServiceClient
from google.cloud.aiplatform_v1.services.match_service.transports import grpc as match_transports_grpc
import grpc
import grpc.experimental.gevent as grpc_gevent
import locust
from locust import between
from locust import env
from locust import FastHttpUser
from locust import task
from locust import User

# patch grpc so that it uses gevent instead of asyncio
grpc_gevent.init_gevent()


@locust.events.init_command_line_parser.add_listener
def _(parser):
  """Add command line arguments to the Locust environment.

  Args:
    parser: parser to add arguments
  """
  parser.add_argument(
      "--deployed-index-id",
      type=str,
      default="ishmeetss_vector_search_pr_1737442634275",
      help="Deployed index id for http calls",
  )
  parser.add_argument(
      "--num-neighbors", type=int, default=20, help="number of neighbors"
  )
  parser.add_argument(
      "--dense-embedding-num-dimensions",
      type=int,
      default=768,
      help=(
          "Number of dimensions for dense embedding. For dense-only embedding",
          "this dimension is the number of total dimensions. For hybrid ",
          "embedding, this dimension is the number of dimensions for the dense",
          "embedding feature vector.",
      ),
  )
  parser.add_argument(
      "--index-endpoint-resource-name",
      type=str,
      default="projects/131502646301/locations/us-central1/indexEndpoints/6509491466480386048",
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
      "--num-embeddings-per-request",
      type=int,
      default=1,
      help="Optional. Number of embeddings per request.",
  )


class VectorSearchPublicEndpointGrpcUser(User):
  """User that connects to Vector Search public endpoint using gRPC."""

  wait_time = between(1, 2)
  host = '613853451.us-central1-131502646301.vdb.vertexai.goog:443'

  def __init__(self, environment: env.Environment):
    super().__init__(environment)
    self.vector_search_resource_name = (
        self.environment.parsed_options.index_endpoint_resource_name
    )
    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    request = google.auth.transport.requests.Request()
    public_channel = google.auth.transport.grpc.secure_authorized_channel(
        credentials,
        request,
        environment.host,
        ssl_credentials=grpc.ssl_channel_credentials(),
    )

    self.data_client = MatchServiceClient(
        transport=match_transports_grpc.MatchServiceGrpcTransport(
            channel=public_channel,
        ),
    )

  @task
  def findNearestNeighbor(self):
    request = FindNeighborsRequest(
        index_endpoint=self.vector_search_resource_name,
        deployed_index_id=self.environment.parsed_options.deployed_index_id,
        return_full_datapoint=self.environment.parsed_options.return_full_datapoint,
    )
    dp = IndexDatapoint(
        datapoint_id="0",
    )
    dp.feature_vector = [
        random.randint(-1000000, 1000000)
        for _ in range(
            self.environment.parsed_options.dense_embedding_num_dimensions
        )
    ]

    query = FindNeighborsRequest.Query(
        datapoint=dp,
        neighbor_count=self.environment.parsed_options.num_neighbors,
    )
    request.queries.append(query)
    start_perf_counter = time.perf_counter()
    try:
      response = self.data_client.find_neighbors(request)
      self.environment.events.request.fire(
          request_type="grpc",
          name="MatchEngine.FindNeighbors",
          response_time=(time.perf_counter() - start_perf_counter) * 1000,
          response=response,
          response_length=0,
      )
    except Exception as e:
      self.environment.events.request.fire(
          request_type="grpc",
          name="MatchEngine.FindNeighbors",
          response_time=(time.perf_counter() - start_perf_counter) * 1000,
          response_length=0,
          exception=e,
      )
