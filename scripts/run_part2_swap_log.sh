#!/bin/bash
set -e
cd /mnt/c/Users/zulfa/Downloads/devops-test
mkdir -p screenshots

# Reset container ke versi 1.0.0
docker rm -f app 2>/dev/null || true
docker run -d --name app -p 8081:8080 --restart unless-stopped hello-devops:1.0.0 >/dev/null
sleep 1

{
  echo "=== SEBELUM SWAP ($(date)) ==="
  docker ps --filter name=app
  curl -s http://localhost:8081
  echo ""

  echo ""
  echo "=== BUILD BINARY BARU DI HOST ==="
  docker rm -f extract 2>/dev/null || true
  docker create --name extract hello-devops:1.0.1 >/dev/null
  docker cp extract:/app ./app-new
  docker rm extract >/dev/null
  ls -lh app-new

  echo ""
  echo "=== SWAP + RESTART ==="
  docker cp app-new app:/app
  docker restart app
  sleep 2

  echo ""
  echo "=== SESUDAH SWAP ($(date)) ==="
  docker ps --filter name=app
  curl -s http://localhost:8081
  echo ""

  echo ""
  echo "=== BUKTI TANPA REBUILD ==="
  docker images hello-devops
} 2>&1 | tee screenshots/part2-swap.log
