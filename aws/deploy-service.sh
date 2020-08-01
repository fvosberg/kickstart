#!/bin/bash
AWS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"


while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$0 - deploy infrastructure and service via cloudformation"
      echo " "
      echo "$0 [options] [dir-to-build]"
      echo " "
      echo "options:"
      echo "-h, --help                              show brief help"
      echo "--infrastructure-stack=[STACK_NAME]     specify the name of the infrastructure stack"
      echo "--service=[SERVICE_NAME]                specify the name of the service"
      echo "-f|--docker-file=[path]                 specify the path of the docker file"
      echo "--router-priority=[number]              the priority of the listener rule in the load balancer"
      exit 0
      ;;

    --infrastructure-stack)
      shift
      if test $# -gt 0; then
        INFRA_STACK_NAME="$1"
      else
        echo -e "\n\nNo stack name specified\n\n"
        exit 1
      fi
      shift
      ;;

    --service)
      shift
      if test $# -gt 0; then
        SERVICE_NAME="$1"
      else
        echo -e "\n\nNo service name specified\n\n"
        exit 1
      fi
      shift
      ;;

    --router-priority)
      shift
      if test $# -gt 0; then
        ROUTER_PRIORITY="$1"
      else
        echo -e "\n\nNo router priority specified\n\n"
        exit 1
      fi
      shift
      ;;

    --docker-image)
      shift
      if test $# -gt 0; then
        DOCKER_IMAGE_URL="$1"
      else
        echo -e "\n\nNo url for --docker-image specified\n\n"
        exit 1
      fi
      shift
      ;;

    --replicas)
      shift
      if test $# -gt 0; then
        REPLICAS="$1"
      else
        echo -e "\n\nNo value for --replicas specified\n\n"
        exit 1
      fi
      shift
      ;;

    --environment-variables-prefix)
      shift
      if test $# -gt 0; then
        ENV_PREFIX="$1"
      else
        echo -e "\n\nNo value for --environment-variables-prefix specified\n\n"
        exit 1
      fi
      shift
      ;;

    -f|--docker-file)
      shift
      if test $# -gt 0; then
        DOCKER_FILE_OPTION="$1"
      else
        echo -e "\n\nNo path for --docker-file specified\n\n"
        exit 1
      fi
      shift
      ;;

    *)
      if [ $# -gt 1 ]; then
        echo -e "\nUnknown flag $1\n"
        exit 1
      else
        break
      fi
      ;;
  esac
done

if [ ! -z "${DOCKER_IMAGE_URL}" ] && [ ! -z "$1" ]; then
  echo -e "\nBoth, a build dir and a docker image url are specified.\nSpecify the docker-image-url to deploy an existing image, specify the build folder for building a new image. The latter is always deployed to the services ECR repository, so specifying both doesn't make sense.\n"
  exit 1
fi

if [ ! -z "$1" ]; then
  BUILD_DIR="$1"
fi

if [ -z "${DOCKER_FILE_OPTION}" ]; then
  DOCKER_FILE="${BUILD_DIR}/Dockerfile"
else
  DOCKER_FILE="${DOCKER_FILE_OPTION}"
fi

if [ "$INFRA_STACK_NAME" == "" ]; then
  echo -e "\n\nMissing infrastructure stack name\n\n$0 --infrastructure-stack [stack-name]\n"
  exit 1
fi

if [ "$SERVICE_NAME" == "" ]; then
  echo -e "\n\nMissing service name\n\n$0 --service [service-name]\n"
  exit 1
fi

if [ "$ROUTER_PRIORITY" == "" ]; then
  echo -e "\n\nMissing router priority\n\n$0 --router-priority [number]\n"
  exit 1
fi

set -e

# repository name => uri (blank if doesn't exist)
function ecrRepositoryUri {
  set +e
  REPO=$(aws ecr describe-repositories --repository-names "$1" 2> /dev/null)
  RETURN=$?
  set -e

  if [ "$RETURN" -eq 0 ]; then
    echo "${REPO}" | jq -r '.repositories[0].repositoryUri'
  fi
}

# stackoutput, field name => field value
function selectFromOutput {
  echo $1 | jq -r "map(select(.OutputKey | contains (\"$2\"))) | .[0].OutputValue"
}

# docker-image-url, other parameters are fetched from the global space
function deployService {
  BASE_STACK=$(aws cloudformation describe-stacks --stack-name "${INFRA_STACK_NAME}" | jq -r ".Stacks[0].Outputs")

  EXECUTION_ROLE="$(selectFromOutput "$BASE_STACK" "ServiceExecutionRole")"
  SERVICE_TASK_ROLE="$(selectFromOutput "$BASE_STACK" "ServiceTaskRole")"
  VPC_ID="$(selectFromOutput "$BASE_STACK" "VPCId")"
 # TODO try private subnets?
  SUBNET_IDS="$(selectFromOutput "$BASE_STACK" "ServiceSubnetIds")"
  DB_HOST="$(selectFromOutput "$BASE_STACK" "DBHost")"
  DB_PORT="$(selectFromOutput "$BASE_STACK" "DBPort")"
  LOAD_BALANCER_LISTENER="$(selectFromOutput "$BASE_STACK" "LoadBalancerListener")"
  ECS_CLUSTER="$(selectFromOutput "$BASE_STACK" "ECSCluster")"
  CONTAINER_SECURITY_GROUP="$(selectFromOutput "$BASE_STACK" "ContainerSecurityGroup")"
  SECRETS_PROVIDER_SERVICE_TOKEN="$(selectFromOutput "$BASE_STACK" "SecretsProviderServiceToken")"
  DATABASE_PROVIDER_SERVICE_TOKEN="$(selectFromOutput "$BASE_STACK" "DatabaseProviderServiceToken")"
  DISCOVERY_SERVICE_ARN="$(selectFromOutput "$BASE_STACK" "DiscoveryServiceArn")"

  set -x

  aws cloudformation deploy \
    --stack-name "${INFRA_STACK_NAME}-${SERVICE_NAME}" \
    --template-file "${AWS_DIR}/service.yaml" \
    --no-fail-on-empty-changeset \
    --parameter-overrides \
      "ServiceName=${SERVICE_NAME}" \
      "DockerImage=$1" \
      "EnvironmentVariablesPrefix=${ENV_PREFIX}" \
      "Replicas=${REPLICAS}" \
      "RouterPriority=${ROUTER_PRIORITY}" \
      "EnvironmentName=${INFRA_STACK_NAME}" \
      "ExecutionRole=${EXECUTION_ROLE}" \
      "ServiceTaskRole=${SERVICE_TASK_ROLE}" \
      "VPCId=${VPC_ID}" \
      "SubnetIds=${SUBNET_IDS}" \
      "DBHost=${DB_HOST}" \
      "DBPort=${DB_PORT}" \
      "LoadBalancerListener=${LOAD_BALANCER_LISTENER}" \
      "ECSCluster=${ECS_CLUSTER}" \
      "ContainerSecurityGroup=${CONTAINER_SECURITY_GROUP}" \
      "SecretsProviderServiceToken=${SECRETS_PROVIDER_SERVICE_TOKEN}" \
      "DatabaseProviderServiceToken=${DATABASE_PROVIDER_SERVICE_TOKEN}" \
      "DiscoveryServiceArn=${DISCOVERY_SERVICE_ARN}" \
      "EnvironmentVariables="
}

if [ -z "${DOCKER_IMAGE_URL}" ]; then
  echo -e "\nChecking for existence of ECR Repo\n"
  ECR_REPO_URI=$(ecrRepositoryUri "${INFRA_STACK_NAME}/${SERVICE_NAME}")

  if [ -z "${ECR_REPO_URI}" ]; then
    echo -e "\nDeploy stack without Fargate service to provide ECR Repository\n"
    deployService ""

    ECR_REPO_URI=$(ecrRepositoryUri "${INFRA_STACK_NAME}/${SERVICE_NAME}")

    if [ -z "${ECR_REPO_URI}" ]; then
      echo -e"retrieving repo URI after creation failed\n\n${REPO}\n"
      exit 1
    fi
  fi

  set +e

  APP_VERSION="dev-$(git symbolic-ref --short HEAD)-$(date -u +"%Y%m%dT%H%M%SZ")"
  IMAGE_URL="${ECR_REPO_URI}:${APP_VERSION}"

  echo -e "\nBuilding image ${IMAGE_URL}\n"

  docker build \
    -f "${DOCKER_FILE}" \
    -t "${IMAGE_URL}" \
    "${BUILD_DIR}"

  $(aws ecr get-login --no-include-email)
  docker push "${IMAGE_URL}"
else
  IMAGE_URL="${DOCKER_IMAGE_URL}"
fi

set -e

echo -e "\nDeploying service with ${IMAGE_URL}\n"

deployService "${IMAGE_URL}"
