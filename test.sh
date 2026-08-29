#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:?Usage: ./test.sh https://verlaine.lesure.net}"
AUDIO_PATH="${2:-/arch/63.トーク・ハラスメント.m4a}"

echo "== healthcheck =="
curl -fsSI "${BASE_URL}/healthcheck.txt"

echo
echo "== RSS =="
curl -fsSI "${BASE_URL}/feed.xml"

echo
echo "== audio HEAD =="
curl -fsSI "${BASE_URL}${AUDIO_PATH}"

echo
echo "== audio Range =="
curl -fsS -D - -r 0-1023 -o /dev/null "${BASE_URL}${AUDIO_PATH}" | \
  grep -Ei 'HTTP/|content-range|accept-ranges|content-length|content-type|x-cache|age' || true

echo
echo "All HTTP checks completed."
