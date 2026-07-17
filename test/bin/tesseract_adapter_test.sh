#!/usr/bin/env bash
set -euo pipefail

ADAPTER="${1:?adapter path is required}"
TEST_ROOT=$(mktemp -d /tmp/tesseract-web-adapter-test.XXXXXX)
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export TESSERACT_WORKTREE_ROOT="$HOME/repos/tesseract-web-worktrees"
export TESSERACT_DOMAIN="tesseract-web.test"
export TESSERACT_PORT_START=6101
export TESSERACT_PORT_END=6103
export TESSERACT_CERT_PATH="$HOME/certs/app.crt"
export TESSERACT_KEY_PATH="$HOME/certs/app.key"
export TEST_TMUX_STATE="$TEST_ROOT/tmux-state"

mkdir -p "$HOME/repos/tesseract-web/bin" "$HOME/repos/tesseract-web/config" \
  "$HOME/repos/tesseract-web/storage" "$HOME/certs" "$TEST_ROOT/stubs"
cp "$ADAPTER" "$HOME/repos/tesseract-web/bin/tesseract"
chmod +x "$HOME/repos/tesseract-web/bin/tesseract"

cat > "$HOME/repos/tesseract-web/bin/rails" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$TEST_ROOT/stubs/bundle" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$TEST_ROOT/stubs/mise" <<'SH'
#!/usr/bin/env bash
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done
[ "$#" -gt 0 ] && shift
exec "$@"
SH
cat > "$TEST_ROOT/stubs/ss" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$TEST_ROOT/stubs/tmux" <<'SH'
#!/usr/bin/env bash
command="${1:-}"
shift || true
case "$command" in
  has-session)
    target="${2#=}"
    grep -qx "$target" "$TEST_TMUX_STATE" 2>/dev/null
    ;;
  new-session)
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "-s" ]; then printf "%s\n" "$2" > "$TEST_TMUX_STATE"; break; fi
      shift
    done
    ;;
  kill-session)
    rm -f "$TEST_TMUX_STATE"
    ;;
  *) exit 0 ;;
esac
SH
chmod +x "$HOME/repos/tesseract-web/bin/rails" "$TEST_ROOT/stubs/"*
export PATH="$TEST_ROOT/stubs:$PATH"

cd "$HOME/repos/tesseract-web"
git init -q -b main
printf "3.4.2\n" > .ruby-version
cat > .gitignore <<'EOF'
/.env*
/storage/*
/config/master.key
EOF
touch .env .env.local config/master.key
sqlite3 storage/production.sqlite3 'CREATE TABLE examples (id INTEGER PRIMARY KEY); INSERT INTO examples DEFAULT VALUES;'
git add .ruby-version .gitignore bin/rails bin/tesseract
git -c user.name=Test -c user.email=test@example.com commit -qm initial

create_output=$(bin/tesseract worktree create demo)
grep -q 'created tesseract-web/demo' <<<"$create_output"
grep -q 'url=https://tesseract-web.test:6101' <<<"$create_output"
[ -f "$TESSERACT_WORKTREE_ROOT/demo/storage/development.sqlite3" ]
[ "$(sqlite3 "$TESSERACT_WORKTREE_ROOT/demo/storage/development.sqlite3" 'SELECT COUNT(*) FROM examples;')" = "1" ]

touch "$TESSERACT_CERT_PATH" "$TESSERACT_KEY_PATH"
start_output=$(bin/tesseract worktree start demo)
grep -q 'tmux_session=tesseract_web_demo' <<<"$start_output"
grep -q 'url=https://tesseract-web.test:6101' <<<"$start_output"

status_output=$(bin/tesseract worktree status demo)
grep -q 'registered=yes' <<<"$status_output"
grep -q 'running=yes' <<<"$status_output"

bin/tesseract worktree stop demo | grep -q 'stopped tesseract_web_demo'
bin/tesseract worktree remove demo | grep -q 'removed tesseract-web/demo'
[ ! -e "$TESSERACT_WORKTREE_ROOT/demo" ]

echo "adapter tests passed"
