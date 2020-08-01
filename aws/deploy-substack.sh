#!/bin/bash
AWS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

set -e

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$0 - deploy infrastructure and service via cloudformation"
      echo " "
      echo "$0 [options] [dir-to-build]"
      echo " "
      echo "options:"
      echo "-h, --help                                    show brief help"
      echo "--infrastructure-stack=[STACK_NAME]           specify the name of the infrastructure stack"
      echo "--service=[SERVICE_NAME]                      specify the name of the service"
      echo "-f|--docker-file=[path]                       specify the path of the docker file"
      echo "--router-priority=[number]                    the priority of the listener rule in the load balancer"
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
        DOCKER_IMAGE="$1"
      else
        echo -e "\n\nNo url for --docker-image specified\n\n"
        exit 1
      fi
      shift
      ;;

    --additional-parameter-overrides)
      shift
      if test $# -gt 0; then
        ADDITIONAL_PARAMETER_OVERRIDES="$1"
        shift
      fi
      ;;

    --template-file)
      shift
      if test $# -gt 0; then
        TEMPLATE_FILE="$1"
      else
        echo -e "\n\nNo template file specified\n\n"
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

    --service-name)
      shift
      if test $# -gt 0; then
        SERVICE_NAME="$1"
      else
        echo -e "\n\nNo service name specified\n\n"
        exit 1
      fi
      shift
      ;;

    *)
      echo -e "\nUnknown option $1\n"
      exit 1
      ;;
  esac
done

if [ "$INFRA_STACK_NAME" == "" ]; then
  echo -e "\n\nMissing infrastructure stack name\n\n$0 --infrastructure-stack [stack-name]\n"
  exit 1
fi

if [ "$ROUTER_PRIORITY" == "" ]; then
  echo -e "\n\nMissing router priority\n\n$0 --router-priority [number]\n"
  exit 1
fi

if [ "$TEMPLATE_FILE" == "" ]; then
  echo -e "\n\nMissing template file\n\n$0 --template-file [path]\n"
  exit 1
fi

if [ "$SERVICE_NAME" == "" ]; then
  echo -e "\n\nMissing service name\n\n$0 --service-name [name]\n"
  exit 1
fi

# stackoutput, field name => field value
function selectFromOutput {
  echo $1 | jq -r "map(select(.OutputKey | contains (\"$2\"))) | .[0].OutputValue"
}

BASE_STACK=$(aws cloudformation describe-stacks --stack-name "${INFRA_STACK_NAME}" | jq -r ".Stacks[0].Outputs")

EXECUTION_ROLE="$(selectFromOutput "$BASE_STACK" "ServiceExecutionRole")"
SERVICE_TASK_ROLE="$(selectFromOutput "$BASE_STACK" "ServiceTaskRole")"
VPC_ID="$(selectFromOutput "$BASE_STACK" "VPCId")"
# TODO try private subnets?
PUBLIC_SUBNET_IDS="$(selectFromOutput "$BASE_STACK" "PublicSubnetIds")"
PRIVATE_SUBNET_IDS="$(selectFromOutput "$BASE_STACK" "PrivateSubnetIds")"
DB_HOST="$(selectFromOutput "$BASE_STACK" "DBHost")"
DB_PORT="$(selectFromOutput "$BASE_STACK" "DBPort")"
LOADBALANCER_LISTENER="$(selectFromOutput "$BASE_STACK" "LoadBalancerListener")"
SECURE_LOADBALANCER_LISTENER="$(selectFromOutput "$BASE_STACK" "SecureLoadBalancerListener")"
ECS_CLUSTER="$(selectFromOutput "$BASE_STACK" "ECSCluster")"
CONTAINER_SECURITY_GROUP="$(selectFromOutput "$BASE_STACK" "ContainerSecurityGroup")"
SECRETS_PROVIDER_SERVICE_TOKEN="$(selectFromOutput "$BASE_STACK" "SecretsProviderServiceToken")"
DATABASE_PROVIDER_SERVICE_TOKEN="$(selectFromOutput "$BASE_STACK" "DatabaseProviderServiceToken")"
PRIVATE_NAMESPACE="$(selectFromOutput "$BASE_STACK" "PrivateNamespace")"

echo "Overriding loadbalancer url to ${LOADBALANCER_URL}\n"
if [ -z "${LOADBALANCER_URL}" ]; then
  echo "NOT Overriding loadbalancer url to ${LOADBALANCER_URL}\n"
  LOADBALANCER_URL="$(selectFromOutput "$BASE_STACK" "LoadBalancerUrl")"
fi

set -x

aws cloudformation deploy \
  --stack-name "${INFRA_STACK_NAME}-${SERVICE_NAME}" \
  --template-file "${TEMPLATE_FILE}" \
  --no-fail-on-empty-changeset \
  --parameter-overrides ${ADDITIONAL_PARAMETER_OVERRIDES}\
    "ServiceName=${SERVICE_NAME}" \
    "DockerImage=${DOCKER_IMAGE}" \
    "RouterPriority=${ROUTER_PRIORITY}" \
    "EnvironmentName=${INFRA_STACK_NAME}" \
    "ExecutionRole=${EXECUTION_ROLE}" \
    "ServiceTaskRole=${SERVICE_TASK_ROLE}" \
    "VPCId=${VPC_ID}" \
    "PublicSubnetIds=${PUBLIC_SUBNET_IDS}" \
    "PrivateSubnetIds=${PRIVATE_SUBNET_IDS}" \
    "DBHost=${DB_HOST}" \
    "DBPort=${DB_PORT}" \
    "LoadBalancerListener=${LOADBALANCER_LISTENER}" \
    "SecureLoadBalancerListener=${SECURE_LOADBALANCER_LISTENER}" \
    "LoadBalancerUrl=${LOADBALANCER_URL}" \
    "ECSCluster=${ECS_CLUSTER}" \
    "ContainerSecurityGroup=${CONTAINER_SECURITY_GROUP}" \
    "SecretsProviderServiceToken=${SECRETS_PROVIDER_SERVICE_TOKEN}" \
    "PrivateNamespace=${PRIVATE_NAMESPACE}" \
    "DatabaseProviderServiceToken=${DATABASE_PROVIDER_SERVICE_TOKEN}" \
    "SSLCertificateArn=${SSL_CERTIFICATE_ARN}"
