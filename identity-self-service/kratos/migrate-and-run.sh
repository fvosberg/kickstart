#!/bin/sh

set -e
set -x

# HACK for Cloud-Run to fulfill the container contract to listen on the port provided by the env:PORT
if [ ! -z "$PORT" ]; then
  echo -e "Migrated the env:PORT for CLOUD_RUN to the env:SERVE_PUBLIC_PORT for kratos\n";

  # Second Hack for Cloud Run, which doesn't allow multiple ports
  if [ -z "$SERVE_ADMIN_ENDPOINT" ] || [ "$SERVE_ADMIN_ENDPOINT" = "false" ]; then
    echo "Serving public api on ${PORT}"
    export SERVE_PUBLIC_PORT="${PORT}"
  else
    echo "Serving admin api on ${PORT}"
    export SERVE_ADMIN_PORT="${PORT}"
  fi
fi

kratos ${MIGRATE_ARGS}
kratos "$@"
