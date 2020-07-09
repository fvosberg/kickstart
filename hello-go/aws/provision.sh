#!/bin/bash
AWS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

set -e

# TODO check jq installed

# TODO gateway?
# TODO cleanup script
CFN_TEMPLATE="${AWS_DIR}/stack.yaml"
REGION=$(aws configure get region)
ACCOUNT=$(aws sts get-caller-identity | jq -r ".Account")
BUCKET_NAME_SHORT="devops-tools"

DATABASE_PROVIDER_PATH="${AWS_DIR}/database-provider-latest.zip"
if [ ! -f "${DATABASE_PROVIDER_PATH}" ]; then
  echo "Recreating database provider zip"
  /Users/frederikvosberg/code/frederikvosberg/cfn-postgres-provider/build.sh --out "${DATABASE_PROVIDER_PATH}"
fi


while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$0 - provisions the infrstructure via cloudformation"
      echo " "
      echo "$0 [options]"
      echo " "
      echo "options:"
      echo "-h, --help                     show brief help"
      echo "-s, --stack=[STACK_NAME]       specify the name for the cloudformation stack"
      echo "-i, --image=[DOCKER_IMAGE_URL] specify the docker image URL to deploy"
      echo "--db-pass-file=[PATH]          specify the path to the file containing the password for the db"
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

    -i|--image)
      shift
      if test $# -gt 0; then
        IMAGE_URL="$1"
      else
        echo -e "\n\nNo image specified\n\n"
        exit 1
      fi
      shift
      ;;

    -r|--region)
      shift
      if test $# -gt 0; then
        REGION="$1"
      else
        echo -e "\n\nNo region specified\n\n"
        exit 1
      fi
      shift
      ;;

    --template-file)
      shift
      if test $# -gt 0; then
        CFN_TEMPLATE="$1"
      else
        echo -e "\n\nNo template file specified\n\n"
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

if [ "$REGION" == "" ]; then
  echo -e "\n\nMissing region - either configure the default region for your account in the CLI or provide one via flag\n\n$0 --region [region]\n"
  exit 1
fi

BUCKET_NAME_FULL="${ACCOUNT}-${REGION}-${BUCKET_NAME_SHORT}"

function ensureBucketExists {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "\nMissing bucket name ($1) or region ($2) in ensureBucketExists\n"
    exit 1
  fi

  set +e
  aws s3api head-bucket --bucket "$1" > /dev/null 2>&1
  RETURN=$?
  set -e

  if [ ! $RETURN -eq 0 ]; then
    aws s3api create-bucket \
      --bucket "$1" \
      --create-bucket-configuration "LocationConstraint=$2"
  fi
}

ensureBucketExists "${BUCKET_NAME_FULL}" "${REGION}"

# package nested stack to upload it with S3 template URIs to S3
aws cloudformation package \
  --template-file "${CFN_TEMPLATE}" \
  --s3-bucket "${BUCKET_NAME_FULL}" \
  --output-template-file "${AWS_DIR}/stack.packaged.yaml"

DATABASE_PROVIDER_ZIP_FILE="custom-providers/$(basename "${DATABASE_PROVIDER_PATH}")"
aws s3 cp "${DATABASE_PROVIDER_PATH}" "s3://${BUCKET_NAME_FULL}/${DATABASE_PROVIDER_ZIP_FILE}"



# deploy the packed stack
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "${AWS_DIR}/stack.packaged.yaml" \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "HelloGophersImage=${IMAGE_URL}" \
    "DatabaseProviderZipFileName=${DATABASE_PROVIDER_ZIP_FILE}" \
    "DatabaseProviderS3Bucket=${BUCKET_NAME_FULL}"
