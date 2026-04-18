#!/bin/bash
# LB へ1秒ごとにリクエストを送り、どのサーバが応答しているか確認するスクリプト
set -euo pipefail

LB_HOST="${1:-192.168.56.10}"
LB_PORT="${2:-80}"
INTERVAL="${3:-1}"

URL="http://${LB_HOST}:${LB_PORT}/"

echo "Polling ${URL} every ${INTERVAL}s ... (Ctrl+C to stop)"
echo "----------------------------------------"

prev_server=""

while true; do
  timestamp=$(date '+%H:%M:%S')
  response=$(curl -s --max-time 3 "${URL}" 2>/dev/null) || true

  if [ -n "$response" ]; then
    server=$(echo "$response" | grep -oP '(?<=<h1>)[^<]+' || echo "unknown")
    ip=$(echo "$response" | grep -oP '(?<=IP: )[^<]+' || echo "")

    if [ "$server" != "$prev_server" ] && [ -n "$prev_server" ]; then
      echo "[${timestamp}] *** サーバ切り替わり ***"
    fi

    echo "[${timestamp}] ${server} (${ip})"
    prev_server="$server"
  else
    echo "[${timestamp}] ERROR: LB に接続できません"
  fi

  sleep "${INTERVAL}"
done
