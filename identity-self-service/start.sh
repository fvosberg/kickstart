#!/bin/bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

case "$1" in
  "local-ui")
    echo "Starting local-ui"
    docker run \
      -e 'KRATOS_PUBLIC_URL=http://kratos:4433' \
      -e 'KRATOS_ADMIN_URL=http://kratos:4434' \
      -e 'PORT=4455' \
      -e 'SECURITY_MODE=cookie' \
      -p 4455:4455 \
      --network 'identity-self-service_default' \
      oryd/kratos-selfservice-ui-node:latest

    if [ "$2" != "local" ]; then
      echo -e "\n\nMissing second argument [kratos url].\n\n"
      exit 2
    fi
    ;;

  *)
    echo -e "\nCommand $1 not found. Please call\n\n\t$0 local-ui\n\n"
    exit 1
    ;;
esac
