#!/bin/bash
AWS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

set -e

# TODO check jq installed
# TODO cleanup script

### START FUNCTIONS

# s3-bucket-name, region
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

# bucket-name, region, zipPath, zipFileName
function uploadCustomProvider {
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo -e "\nMissing bucket-name ($1), region ($2) or zipPath ($3)\n"
    exit 1
  fi

  ensureBucketExists "$1" "$2"

  aws s3 cp "$3" "s3://$1/${DATABASE_PROVIDER_ZIP_FILE}"
}

### END FUNCTIONS

### START PARAMETER DEFAULTS

ROOT_STACK_TEMPLATE="${AWS_DIR}/infrastructure.yaml"
REGION=$(aws configure get region)
ACCOUNT=$(aws sts get-caller-identity | jq -r ".Account")
BUCKET_NAME_SHORT="devops-tools"

### END PARAMETER DEFAULTS

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$0 - deploy infrastructure and service via cloudformation"
      echo " "
      echo "$0 [options]"
      echo " "
      echo "options:"
      echo "-h, --help                           show brief help"
      echo "--stack=[STACK_NAME]                 specify the name for the cloudformation stack"
      echo "--region=[REGION]                    specify the region"
      echo "--database-providere-path=[PATH]     a path to the zip with the database provider to upload"
      exit 0
      ;;

    --stack)
      shift
      if test $# -gt 0; then
        STACK_NAME="$1"
      else
        echo -e "\n\nNo stack specified\n\n"
        exit 1
      fi
      shift
      ;;

    --region)
      shift
      if test $# -gt 0; then
        REGION="$1"
      else
        echo -e "\n\nNo region specified\n\n"
        exit 1
      fi
      shift
      ;;

    --database-provider-path)
      shift
      if test $# -gt 0; then
        DATABASE_PROVIDER_PATH="$1"
      else
        echo -e "\n\nNo path to a database provider zip specified\n\n"
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
      break
      ;;
  esac
done

### START PARAMETER VALIDATION

if [ "$STACK_NAME" == "" ]; then
  echo -e "\n\nMissing stack name\n\n$0 --stack [stack-name]\n"
  exit 1
fi

if [ "$REGION" == "" ]; then
  echo -e "\n\nMissing region - either configure the default region for your account in the CLI or provide one via flag\n\n$0 --region [region]\n"
  exit 1
fi

if [ "$DATABASE_PROVIDER_PATH" == "" ]; then
  echo -e "\n\nMissing path to the database provider zip to upload. You can generate via github.com/fvosberg/cfn-postgres-provider\n\n$0 --database-provider-path [path]\n"
  exit 1
fi

BUCKET_NAME_FULL="${ACCOUNT}-${REGION}-${BUCKET_NAME_SHORT}"

### END PARAMETER VALIDATION

set -e


DATABASE_PROVIDER_ZIP_FILE="custom-providers/$(basename "$DATABASE_PROVIDER_PATH")"
uploadCustomProvider "${BUCKET_NAME_FULL}" "${REGION}" "${DATABASE_PROVIDER_PATH}" "${DATABASE_PROVIDER_ZIP_FILE}"

PACKAGED_PATH="${AWS_DIR}/packaged-$(basename $ROOT_STACK_TEMPLATE)"
aws cloudformation package \
  --template-file "$ROOT_STACK_TEMPLATE" \
  --s3-bucket "$BUCKET_NAME_FULL" \
  --output-template-file "${PACKAGED_PATH}"

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "${PACKAGED_PATH}" \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "DatabaseProviderZipFileName=${DATABASE_PROVIDER_ZIP_FILE}" \
    "DatabaseProviderS3Bucket=${BUCKET_NAME_FULL}" \
    "SSLCertificateArn=${SSL_CERTIFICATE_ARN}"

rm "${PACKAGED_PATH}"
