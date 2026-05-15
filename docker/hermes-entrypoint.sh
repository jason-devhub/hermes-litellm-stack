#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/opt/data}"

# Même garde que le gateway Hermes : 0.0.0.0 exige une clé API
_api_host="${API_SERVER_HOST:-0.0.0.0}"
_api_enabled="${API_SERVER_ENABLED:-true}"
if [ "$_api_enabled" = "true" ] && [ "$_api_host" = "0.0.0.0" ] && [ -z "${API_SERVER_KEY:-}" ]; then
    echo "ERROR: API_SERVER_KEY (HERMES_API_SERVER_KEY dans .env) est vide."
    echo "  → Génère une clé : openssl rand -hex 32"
    echo "  → Ajoute HERMES_API_SERVER_KEY=... dans .env ou Coolify → Environment"
    exit 1
fi

# Coolify/Docker can leave a directory at this path when a file bind mount fails.
# Hermes expects config.yaml to be a file and its official entrypoint will create it.
if [ -d "$HERMES_HOME/config.yaml" ]; then
    rm -rf "$HERMES_HOME/config.yaml"
fi

exec /usr/bin/tini -g -- /opt/hermes/docker/entrypoint.sh "$@"
