#!/bin/bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"


if [ ! -f "${PROJECT_ROOT}/db_pass" ]; then
  echo -e "\nDatabase password file ${PROJECT_ROOT}/db_pass does not exist\n"
  exit 1
fi
if [ ! -s "${PROJECT_ROOT}/db_pass" ]; then
  echo -e "\nDatabase password file ${PROJECT_ROOT}/db_pass is empty\n"
  exit 1
fi

# TODO ensure right project
#
gcloud config set run/platform managed
gcloud config set run/region europe-west1
cd "${PROJECT_ROOT}"

if [[ "$(gcloud sql instances describe postgres 2>&1)" == *"HTTPError 404"* ]]; then
  gcloud services enable sql-component.googleapis.com sqladmin.googleapis.com
  gcloud sql instances create postgres \
    --database-version=POSTGRES_12 \
    --tier=db-f1-micro \
    --region=europe-west1
  gcloud sql users set-password postgres \
    --instance=postgres \
    --password="$(cat "${PROJECT_ROOT}/db_pass")"
else
  gcloud sql instances patch postgres \
    --tier=db-f1-micro
fi

  gcloud sql users set-password postgres \
    --instance=postgres \
    --password="$(cat "${PROJECT_ROOT}/db_pass")"

gcloud builds submit --tag "gcr.io/fvosbe-bachelor-thesis/hello-go"

# create service
gcloud beta run services replace "${PROJECT_ROOT}/gcp/service.yaml"

# deploy new image
gcloud run deploy hello-go --image "gcr.io/fvosbe-bachelor-thesis/hello-go"

gcloud run deploy gateway \
    --image="gcr.io/endpoints-release/endpoints-runtime-serverless:2" \
    --allow-unauthenticated \
    --platform managed

gcloud beta run domain-mappings create --service gateway --domain thesis-gcp.frederikvosberg.de

gcloud endpoints services deploy "${PROJECT_ROOT}/gcp/gateway-openapi.yaml"
