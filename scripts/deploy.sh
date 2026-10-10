#!/bin/sh
# Swap binary di container yang sedang jalan, health check, rollback otomatis.
set -eu
IMAGE="$1"; CONTAINER="${2:-app}"
HEALTH_URL="${HEALTH_URL:-http://host.docker.internal:8080/}"

docker rm -f extract >/dev/null 2>&1 || true
docker create --name extract "$IMAGE" >/dev/null
docker cp extract:/app ./app-new
docker rm extract >/dev/null

# Backup binary lama untuk rollback
docker cp "$CONTAINER":/app ./app-backup

docker cp ./app-new "$CONTAINER":/app
docker restart "$CONTAINER"

for i in 1 2 3 4 5; do
  sleep 2
  if curl -fs "$HEALTH_URL" >/dev/null; then
    echo "Deploy OK"; exit 0
  fi
done

echo "Health check gagal, rollback..."
docker cp ./app-backup "$CONTAINER":/app
docker restart "$CONTAINER"
exit 1
