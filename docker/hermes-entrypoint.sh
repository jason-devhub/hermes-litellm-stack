#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/opt/data}"

# Coolify/Docker can leave a directory at this path when a file bind mount fails.
# Hermes expects config.yaml to be a file and its official entrypoint will create it.
if [ -d "$HERMES_HOME/config.yaml" ]; then
    rm -rf "$HERMES_HOME/config.yaml"
fi

exec /usr/bin/tini -g -- /opt/hermes/docker/entrypoint.sh "$@"
