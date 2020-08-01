#!/bin/bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

PROJECT_ID="fvosbe-bachelor-thesis"
GATEWAY_CLOUD_RUN_SERVICE="manual-gateway"
GATEWAY_CLOUD_RUN_SERVICE_NAME="manual-gateway-xm2ikhjgta-ew.a.run.app"

gcloud config set run/platform managed
gcloud config set run/region europe-west1

set -e

case "$1" in
  infrastructure)

    gcloud services enable servicemanagement.googleapis.com
    gcloud services enable servicecontrol.googleapis.com
    gcloud services enable endpoints.googleapis.com

    cd "${PROJECT_ROOT}/gcp-terraform"

    terraform init
    terraform plan
    terraform apply


    ;;

  loadbalancer)
    echo -e "\nthis is in beta and doesn't work well\n"
    exit 1
    gcloud beta compute network-endpoint-groups create hello-gophers-serverless-neg \
      --region=europe-west1 \
      --network-endpoint-type=SERVERLESS  \
      --cloud-run-service=hello-gophers
    gcloud compute backend-services create hello-gophers-backend-service \
      --global
    gcloud beta compute backend-services add-backend hello-gophers-backend-service \
      --global \
      --network-endpoint-group=hello-gophers-serverless-neg \
      --network-endpoint-group-region=europe-west1

    gcloud compute url-maps create hello-gophers-url-map \
      --default-service hello-gophers-backend-service

    gcloud compute target-http-proxies create manual-loadbalancer-http-proxy \
      --url-map=hello-gophers-url-map

    gcloud compute forwarding-rules create http-content-rule \
      --target-http-proxy=manual-loadbalancer-http-proxy \
      --global \
      --ports=443
    ;;

  gateway)

    # UPLOAD NEW CONFIG
    gcloud endpoints services deploy "${PROJECT_ROOT}/gcp-terraform/openapi-manual.yaml"
    CONFIG_ID=$(gcloud endpoints configs list --service="${GATEWAY_CLOUD_RUN_SERVICE_NAME}" --limit 1 --format json | jq -r ".[0].id")

    echo "Setting Config ${CONFIG_ID}"


    # BUILD NEW ESP IMAGE FROM CONFIG
    "${PROJECT_ROOT}/gcp-terraform/cloud_run_service/build_esp_image.sh" -s "${GATEWAY_CLOUD_RUN_SERVICE_NAME}" -c "${CONFIG_ID}" -p "${PROJECT_ID}"


    # DEPLOY NEW ESP IMAGE
    gcloud run deploy ${GATEWAY_CLOUD_RUN_SERVICE} \
      --image="gcr.io/fvosbe-bachelor-thesis/endpoints-runtime-serverless:${GATEWAY_CLOUD_RUN_SERVICE_NAME}-${CONFIG_ID}" \
    --allow-unauthenticated --platform managed \
    --service-account \
    manual-gateway-iam@fvosbe-bachelor-thesis.iam.gserviceaccount.com

    ;;

  service)

    cd "${PROJECT_ROOT}"

    gcloud builds submit --tag "gcr.io/fvosbe-bachelor-thesis/hello-go"

    # ensure current image
    gcloud run deploy hello-gophers --image "gcr.io/fvosbe-bachelor-thesis/hello-go"

    ;;
  *)
    echo -e "\nMISSING COMMAND\n\t$0 (service|gateway|infrastructure)\n"
    exit 1
    ;;
esac
