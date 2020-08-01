#!/bin/bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

set -e

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$0 - the kratos self service stack in a running infrastructure stack. If you don't have one running, look at github.com/fvosberg/kickstart/aws"
      echo " "
      echo "$0 [options]"
      echo " "
      echo "options:"
      echo "-h, --help                           show brief help"
      echo "--infrastructure-stack=[STACK_NAME]                 specify the name for the cloudformation stack"
      exit 0
      ;;

    --infrastructure-stack)
      shift
      if test $# -gt 0; then
        STACK_NAME="$1"
      else
        echo -e "\n\nNo stack specified\n\n"
        exit 1
      fi
      shift
      ;;

    --override-loadbalancer-url)
      shift
      if test $# -gt 0; then
        LOADBALANCER_URL="$1"
      else
        echo -e "\n\nNo url for --override-loadbalancer-url specified\n\n"
        exit 1
      fi
      shift
      ;;

    --ssl-certificate-arn)
      shift
      if test $# -gt 0; then
        SSL_CERTIFICATE_ARN="$1"
      else
        echo -e "\n\nNo value for --ssl-certificate-arn specified\n\n"
        exit 1
      fi
      shift
      ;;

    *)
      echo -e "\nUnknown parameter $1\n"
      exit 1
      break
      ;;
  esac
done

if [ "$STACK_NAME" == "" ]; then
  echo -e "\n\nMissing stack name\n\n$0 --infrastructure-stack [stack-name]\n"
  exit 1
fi

function ecrRepositoryUri {
  set +e
  REPO=$(aws ecr describe-repositories --repository-names "$1" 2> /dev/null)
  RETURN=$?
  set -e

  if [ "$RETURN" -eq 0 ]; then
    echo "${REPO}" | jq -r '.repositories[0].repositoryUri'
  fi
}

# docker-image
function deploySubstack {
  "${PROJECT_ROOT}/../aws/deploy-substack.sh" \
    --infrastructure-stack "${STACK_NAME}" \
    --service-name kratos \
    --docker-image "$1" \
    --router-priority 10 \
    --template-file "${PROJECT_ROOT}/aws-vpc/cloudformation.yaml" \
    --override-loadbalancer-url "${LOADBALANCER_URL}" \
    --ssl-certificate-arn "${SSL_CERTIFICATE_ARN}"
}

ECR_REPO_URI=$(ecrRepositoryUri "${STACK_NAME}/kratos")

if [ -z "${ECR_REPO_URI}" ]; then
  echo -e "\nDeploy stack without Fargate service to provide ECR Repository\n"
  deploySubstack ""

  ECR_REPO_URI=$(ecrRepositoryUri "${STACK_NAME}/kratos")

  if [ -z "${ECR_REPO_URI}" ]; then
    echo -e"retrieving repo URI after creation failed\n\n${REPO}\n"
    exit 1
  fi
fi

APP_VERSION="dev-$(git symbolic-ref --short HEAD)-$(date -u +"%Y%m%dT%H%M%SZ")"
IMAGE_URL="${ECR_REPO_URI}:${APP_VERSION}"

docker build -t "$IMAGE_URL" -f "${PROJECT_ROOT}/kratos/Dockerfile" "${PROJECT_ROOT}/kratos"

if [[ "$(aws --version)" = "aws-cli/2"* ]]; then
  echo -e "\nUsing aws cli v2\n"
  aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin "${ECR_REPO_URI}"
else
  echo -e "\nUsing aws cli v1\n"
  $(aws ecr get-login --region eu-central-1 --no-include-email)
fi
docker push "${IMAGE_URL}"

deploySubstack "${IMAGE_URL}"
