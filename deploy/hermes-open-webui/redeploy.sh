#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
ENV_FILE="$SCRIPT_DIR/.env.runtime"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy .env.example to .env.runtime and fill in real values." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

IMAGE_TAG=${IMAGE_TAG:-open-webui:hermes-delete-hook-local}
CONTAINER_NAME=${CONTAINER_NAME:-open-webui}
HOST_BIND_IP=${HOST_BIND_IP:-10.13.37.106}
HOST_BIND_PORT=${HOST_BIND_PORT:-3000}
DATA_VOLUME=${DATA_VOLUME:-open-webui}

required_vars=(
  OPENAI_API_BASE_URL
  OPENAI_API_KEY
  WEBUI_SECRET_KEY
  ENABLE_FORWARD_USER_INFO_HEADERS
  ENABLE_OLLAMA_API
)
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Required variable $var is empty in $ENV_FILE" >&2
    exit 1
  fi
done

BUILD_HASH=$(git -C "$REPO_ROOT" rev-parse --short HEAD)

echo "==> Building ${IMAGE_TAG} from overlay Dockerfile (git ${BUILD_HASH})"
sudo -n docker build \
  -f "$SCRIPT_DIR/Dockerfile.overlay" \
  --build-arg BUILD_HASH="$BUILD_HASH" \
  -t "$IMAGE_TAG" \
  "$REPO_ROOT"

echo "==> Replacing container ${CONTAINER_NAME}"
sudo -n docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
sudo -n docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --add-host host.docker.internal:host-gateway \
  -p "${HOST_BIND_IP}:${HOST_BIND_PORT}:8080" \
  -v "${DATA_VOLUME}:/app/backend/data" \
  -e OPENAI_API_BASE_URL="$OPENAI_API_BASE_URL" \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" \
  -e ENABLE_FORWARD_USER_INFO_HEADERS="$ENABLE_FORWARD_USER_INFO_HEADERS" \
  -e ENABLE_OLLAMA_API="$ENABLE_OLLAMA_API" \
  -e ANONYMIZED_TELEMETRY="${ANONYMIZED_TELEMETRY:-false}" \
  -e DO_NOT_TRACK="${DO_NOT_TRACK:-true}" \
  -e AUXILIARY_EMBEDDING_MODEL="${AUXILIARY_EMBEDDING_MODEL:-TaylorAI/bge-micro-v2}" \
  -e RAG_EMBEDDING_MODEL="${RAG_EMBEDDING_MODEL:-sentence-transformers/all-MiniLM-L6-v2}" \
  "$IMAGE_TAG" >/dev/null

echo "==> Waiting for health"
for _ in $(seq 1 60); do
  status=$(sudo -n docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CONTAINER_NAME")
  echo "$status"
  if [[ "$status" == "healthy" ]]; then
    break
  fi
  sleep 2
done

sudo -n docker inspect "$CONTAINER_NAME" --format 'IMAGE={{.Config.Image}} STATUS={{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'
curl -fsS "http://${HOST_BIND_IP}:${HOST_BIND_PORT}/health"
