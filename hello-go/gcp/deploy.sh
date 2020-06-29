#!/bin/bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

# TODO ensure right project
#
gcloud config set run/platform managed
gcloud config set run/region europe-west1
cd "${PROJECT_ROOT}"

gcloud builds submit --tag "gcr.io/fvosbe-bachelor-thesis/hello-go"

gcloud beta run services replace "${PROJECT_ROOT}/gcp/service.yaml"
