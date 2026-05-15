#!/bin/sh
set -e

# fast-model et les alias nvidia_* lisent os.environ/NVIDIA_API_KEY dans litellm-config.yaml
if [ -z "${NVIDIA_API_KEY:-}" ]; then
  echo "ERROR: NVIDIA_API_KEY est vide."
  echo "  → Crée une clé sur https://build.nvidia.com (format nvapi-...)"
  echo "  → Ajoute NVIDIA_API_KEY=... dans .env (local) ou dans Coolify → Environment"
  exit 1
fi

exec litellm --config /app/proxy_server_config.yaml --host 0.0.0.0 --port 4000
