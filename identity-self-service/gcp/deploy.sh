#!/bin/bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

PROJECT_ID="fvosbe-bachelor-thesis"
GATEWAY_CLOUD_RUN_SERVICE="manual-gateway"
GATEWAY_CLOUD_RUN_SERVICE_NAME="manual-gateway-xm2ikhjgta-ew.a.run.app"

gcloud config set run/platform managed
gcloud config set run/region europe-west1

set -e

case "$1" in
  testimages)
    for i in {1..5}; do
      gcloud builds submit --tag "gcr.io/${PROJECT_ID}/kratos:deployment-$i" \
        "${PROJECT_ROOT}/kratos"
    done
    ;;

  infrastructure)

    gcloud services enable servicemanagement.googleapis.com
    gcloud services enable servicecontrol.googleapis.com
    gcloud services enable endpoints.googleapis.com

    UI_IMAGE="gcr.io/${PROJECT_ID}/kratos-ui"
    gcloud builds submit --tag "${UI_IMAGE}" "${PROJECT_ROOT}/kratos-ui"

    KRATOS_IMAGE="gcr.io/${PROJECT_ID}/kratos"
    gcloud builds submit --tag "${KRATOS_IMAGE}" "${PROJECT_ROOT}/kratos"

    cd "${PROJECT_ROOT}/gcp"

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

  service)

    UI_IMAGE="gcr.io/${PROJECT_ID}/kratos-ui"
    gcloud builds submit --tag "${UI_IMAGE}" "${PROJECT_ROOT}/kratos-ui"

    KRATOS_IMAGE="gcr.io/${PROJECT_ID}/kratos"
    gcloud builds submit --tag "${KRATOS_IMAGE}" "${PROJECT_ROOT}/kratos"

    # ensure current image
    gcloud run deploy kratos-admin --image "${KRATOS_IMAGE}"
    gcloud run deploy kratos-public --image "${KRATOS_IMAGE}"

    gcloud run deploy kratos-ui --image "${UI_IMAGE}"

    ;;
  *)
    echo -e "\nMISSING COMMAND\n\t$0 (service|gateway|infrastructure)\n"
    exit 1
    ;;
esac
