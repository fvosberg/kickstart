#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

# TODO first provision
# TODO retrieve ecr url from aws ecr cli
# TODO help text

# TODO check jq installation
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$package - attempt to capture frames"
      echo " "
      echo "$package [options] application [arguments]"
      echo " "
      echo "options:"
      echo "-h, --help                show brief help"
      echo "-a, --action=ACTION       specify an action to use"
      echo "-o, --output-dir=DIR      specify a directory to store output in"
      exit 0
      ;;

    -s|--stack)
      shift
      if test $# -gt 0; then
        STACK_NAME="$1"
      else
        echo -e "\n\nNo stack specified\n\n"
        exit 1
      fi
      shift
      ;;

    *)
      break
      ;;
  esac
done

if [ "$STACK_NAME" == "" ]; then
  echo -e "\n\nMissing stack name\n\n$0 --stack [stack-name]\n"
  exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity | jq -r ".Account")
AWS_REGION=$(aws configure get region)
if [ "$AWS_REGION" == "" ]; then
  echo -e "\nNo default region is set. This is needed to determine the ECR URLs prior to provisioning\n"
  exit 1
fi

set -e
set -x

APP_VERSION="dev-$(git symbolic-ref --short HEAD)-$(date -u +"%Y%m%dT%H%M%SZ")"
IMAGE_URL="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${STACK_NAME}/hello-gophers:${APP_VERSION}"

docker build \
  -f "${PROJECT_ROOT}/Dockerfile" \
  -t "${IMAGE_URL}" \
  "${PROJECT_ROOT}"
# TODO retrieve url from cloudformation or at least the region / not from the default region

$(aws ecr get-login --region ${AWS_REGION} --no-include-email)


# TODO, check if ecr exists
echo -e "\nDeploy stack without image URL\n"

"${PROJECT_ROOT}/aws/provision.sh" --stack devclops --db-pass-file "${PROJECT_ROOT}/aws/db_pass"

docker push "${IMAGE_URL}"

echo -e "\nDeploy stack with image URL\n"
"${PROJECT_ROOT}/aws/provision.sh" --stack devclops --db-pass-file "${PROJECT_ROOT}/aws/db_pass" -i "${IMAGE_URL}"
