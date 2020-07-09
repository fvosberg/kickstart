#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

# TODO configurable and parameter to cloudformation
SERVICE_NAME="hello-gophers"

# TODO check jq installation
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$0 - deploy infrastructure and service via cloudformation"
      echo " "
      echo "$0 [options]"
      echo " "
      echo "options:"
      echo "-h, --help                     show brief help"
      echo "-s, --stack=[STACK_NAME]       specify the name for the cloudformation stack"
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

set -e

AWS_ACCOUNT=$(aws sts get-caller-identity | jq -r ".Account")
AWS_REGION=$(aws configure get region)
if [ "$AWS_REGION" == "" ]; then
  echo -e "\nNo default region is set. This is needed to determine the ECR URLs prior to provisioning\n"
  exit 1
fi

### START
#echo -e "\nDeploy stack without Fargate service to speed up process\n"

#"${PROJECT_ROOT}/aws/provision.sh" --stack "${STACK_NAME}"
#exit 0
### END


set +e
REPO=$(aws ecr describe-repositories --repository-names "${STACK_NAME}/${SERVICE_NAME}" 2> /dev/null)
RETURN=$?
set -e

if [ ! $RETURN -eq 0 ]; then
  echo -e "\nDeploy stack without Fargate service to provide ECR Repository\n"

  "${PROJECT_ROOT}/aws/provision.sh" --stack "${STACK_NAME}"

  set +e
  REPO=$(aws ecr describe-repositories --repository-names "${STACK_NAME}/${SERVICE_NAME}")
  RETURN=$?
  set -e

  if [ ! $RETURN -eq 0 ]; then
    echo -e"retrieving repo URI afteer creation failed\n\n${REPO}\n"
    exit 1
  fi
fi

APP_VERSION="dev-$(git symbolic-ref --short HEAD)-$(date -u +"%Y%m%dT%H%M%SZ")"
IMAGE_URL="$(echo "${REPO}" | jq -r '.repositories[0].repositoryUri'):${APP_VERSION}"

set -e
set -x

docker build \
  -f "${PROJECT_ROOT}/Dockerfile" \
  -t "${IMAGE_URL}" \
  "${PROJECT_ROOT}"

$(aws ecr get-login --region ${AWS_REGION} --no-include-email)


docker push "${IMAGE_URL}"

echo -e "\nDeploy stack with image URL\n"
"${PROJECT_ROOT}/aws/provision.sh" --stack "${STACK_NAME}" -i "${IMAGE_URL}"
