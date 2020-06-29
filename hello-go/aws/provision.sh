#!/bin/bash
AWS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

set -e

# TODO Check AWS configured?
# TODO check jq installed

# TODO gateway?
# TODO cleanup script

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


    --db-pass-file)
      shift
      if test $# -gt 0; then
        DB_PASS="$(cat $1)"
      else
        echo -e "\n\nNo db password file path specified\n\n"
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

if [ "$DB_PASS" == "" ]; then
  echo -e "\n\nMissing db password - either the password file hasn't been provided nor the password file is emtpy\n\n$0 --db-pass-file [path]\n"
  exit 1
fi

echo "\nImage url: ${IMAGE_URL}\n"

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "${AWS_DIR}/stack.yml" \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "DBPassword=${DB_PASS}" \
    "HelloGophersImage=${IMAGE_URL}"

exit 0

  --capabilities CAPABILITY_NAMED_IAM \

OPERATION=create-stack
WAIT_FOR=stack-create-complete

# TODO check if jq is installed
set +e
STACK_JSON=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" 2> /dev/null)
DESCRIBE_STACK_RETURN=$?
set -e
# this stack already exists
if [ $DESCRIBE_STACK_RETURN -eq 0 ]; then
  OPERATION=update-stack
  WAIT_FOR=stack-update-complete

  STACK_STATUS="$(echo $STACK_JSON | jq -r ".Stacks[0].StackStatus")"

  # AWS doesn't allow stack updates on rolled back stacks to force error investigation
  # we don't want that, so we are deleting the rolled back stack and are recreating it
  if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]; then
    echo -e "\nDeleting rolled back stack.\n"
    aws cloudformation delete-stack --stack-name "$STACK_NAME"
    echo -e "\nWaiting for stack deletion to complete\n"
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
    echo -e "\nStack deletion completed\n"
    OPERATION=create-stack
  fi
fi

#HELLO_GOPHERS_IMAGE_URL="332349559535.dkr.ecr.eu-central-1.amazonaws.com/devclops/hello-gophers:dev-master-20200625T071558Z"


echo -e "\nWaiting for ${WAIT_FOR}\n"

aws cloudformation wait "$WAIT_FOR" --stack-name "$STACK_NAME"

echo -e "\nSuccessful ${WAIT_FOR}\n"
