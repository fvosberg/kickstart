#!/bin/bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

REGISTRY_NAME="thesis"
PROJECT_NAME="thesis"
REGISTRY_URL="${REGISTRY_NAME}.azurecr.io"

if [ "$1" = "test" ]; then
  az acr login --name "${REGISTRY_NAME}"

  for i in {1..5}; do
    docker build -t "${REGISTRY_URL}/${PROJECT_NAME}/kratos:deployment-$i" \
      "${PROJECT_ROOT}/kratos"

    docker push "${REGISTRY_URL}/${PROJECT_NAME}/kratos:deployment-$i"
  done

  exit 1
fi

# TODO error on empty
ACR_PASSWORD="$(cat "${PROJECT_ROOT}/azure/acr-password")"

if [ "$1" != "--without-push" ]; then

# TODO check if we have to set versions in order to deploy new container
docker build -t "${REGISTRY_URL}/${PROJECT_NAME}/kratos-ui" "${PROJECT_ROOT}/kratos-ui"
docker build -t "${REGISTRY_URL}/${PROJECT_NAME}/kratos" "${PROJECT_ROOT}/kratos"

az acr login --name "${REGISTRY_NAME}"

docker push "${REGISTRY_URL}/${PROJECT_NAME}/kratos-ui"
docker push "${REGISTRY_URL}/${PROJECT_NAME}/kratos"

fi

cd "${PROJECT_ROOT}/azure"

terraform init
terraform apply \
  -auto-approve \
  -var "kratos-ui-image=${REGISTRY_URL}/${PROJECT_NAME}/kratos-ui" \
  -var "kratos-image=${REGISTRY_URL}/${PROJECT_NAME}/kratos" \
  -var "acr-password=${ACR_PASSWORD}"
