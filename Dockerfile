FROM locustio/locust
WORKDIR /tasks

# Copy files with appropriate permissions already set
COPY --chmod=644 public_http_query.py ./
COPY --chmod=644 config/locust_config.env ./

# Install dependencies
RUN pip install -U google-auth google-cloud-storage google-cloud-logging python-dotenv google-cloud-aiplatform grpcio grpc_interceptor grpcio-status