"""Locust file for http load testing public VVS endpoints."""

import random

import google.auth
import google.auth.transport.requests
import locust
from locust import between
from locust import env
from locust import FastHttpUser
from locust import task


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
      "--num-dimensions", type=int, default=768, help="number of dimensions"
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


class VectorSearchPublicEndpointHttpUser(FastHttpUser):
  """User that connects to Vector Search public endpoint using http."""
  wait_time = between(1, 2)
  host = 'https://613853451.us-central1-131502646301.vdb.vertexai.goog'

  def __init__(self, environment: env.Environment):
    super().__init__(environment)
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
