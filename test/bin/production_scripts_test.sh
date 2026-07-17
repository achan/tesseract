#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

bash -n "$ROOT/bin/prod"
bash -n "$ROOT/bin/deploy"
bash -n "$ROOT/bin/stop-prod"
bash -n "$ROOT/bin/install-production-services"

grep -q 'exec bin/rails server' "$ROOT/bin/prod"
grep -q 'ssl://0.0.0.0' "$ROOT/bin/prod"
if grep -q 'cloudflared' "$ROOT/bin/prod"; then
  echo "bin/prod must not supervise cloudflared" >&2
  exit 1
fi

grep -q 'PORT=6100' "$ROOT/config/systemd/user/tesseract-web-production.service"
grep -q 'BIND=ssl://0.0.0.0:6100' "$ROOT/config/systemd/user/tesseract-web-production.service"
grep -q -- '--config /home/bot/.config/tesseract/tesseract-web-tunnel.yml' \
  "$ROOT/config/systemd/user/tesseract-web-tunnel.service"
if grep -Eq -- '--token(-file)? ' "$ROOT/config/systemd/user/tesseract-web-tunnel.service"; then
  echo "tunnel credentials must not appear in process arguments" >&2
  exit 1
fi

echo "production script tests passed"
