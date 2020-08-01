#!/bin/bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$0 - the hello gophers service in a running infrastructure stack. If you don't have one running, look at github.com/fvosberg/kickstart/aws"
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

    *)
      break
      ;;
  esac
done

"${PROJECT_ROOT}/../aws/deploy-service.sh" \
  --infrastructure-stack "${STACK_NAME}" \
  --service hello-gophers \
  --router-priority ${ROUTER_PRIORITY} \
  --replicase 2 \
  --environment-variables-prefix "HELLO" \
  "${PROJECT_ROOT}"
