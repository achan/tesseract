#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

bash -n "$ROOT/bin/prod"
bash -n "$ROOT/bin/deploy"
bash -n "$ROOT/bin/stop-prod"
bash -n "$ROOT/bin/install-production-services"

grep -q 'exec bin/rails server' "$ROOT/bin/prod"
grep -q 'tcp://127.0.0.1' "$ROOT/bin/prod"
if grep -q 'cloudflared' "$ROOT/bin/prod"; then
  echo "bin/prod must not supervise cloudflared" >&2
  exit 1
fi

grep -q 'BIND=tcp://127.0.0.1:6001' "$ROOT/config/systemd/user/tesseract-web-production.service"
grep -q -- '--token-file /home/bot/.config/tesseract/tesseract-web-tunnel.token' \
  "$ROOT/config/systemd/user/tesseract-web-tunnel.service"
if grep -q -- '--token ' "$ROOT/config/systemd/user/tesseract-web-tunnel.service"; then
  echo "tunnel token must not appear in process arguments" >&2
  exit 1
fi

echo "production script tests passed"
