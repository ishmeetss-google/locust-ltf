FROM locustio/locust
WORKDIR /tasks
COPY *.py ./
RUN pip install -U google-auth google-cloud-storage google-cloud-logging python-dotenv google-cloud-aiplatform grpcio grpc_interceptor grpcio-status
