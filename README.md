# Kickstart Packages

This Repository is in a very early stage.

The different kickstart packages provide a boilerplate for different use cases.
Every package should contain deployments to:

- docker-compose.yml (for local development)
- Kubernetes
- AWS Fargate
- GCP Cloud Run
- Azure Container Instances

## Identity Self Service

The identity self service kickstart package leverages ory.sh Kratos to provide a
service for registration and login. 

## Hello Go

Hello Go provides a simple Go application, which writes and reads data from/to a
Postgres database.


Made with ♥ by Frederik Vosberg
