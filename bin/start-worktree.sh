#!/bin/bash

# start-worktree.sh
# Starts a Rails worktree with a tmux session
#
# Usage: start-worktree.sh
#
# This script:
# - Finds first available port starting from 3000
# - Creates a tmux session with:
#   - Window 1 (main): vim (top), console (bottom-left), claude (bottom-right)
#   - Window 2 (server): Procfile.dev processes (web, jobs) on the found port

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine session name from folder name
SESSION_NAME=$(basename "$PWD")

# Find first available port starting from 3000
START_PORT=6000
MAX_ATTEMPTS=100
PORT=""

echo -e "${BLUE}→ Looking for available port starting from ${START_PORT}...${NC}"

for ((CHECK_PORT=START_PORT; CHECK_PORT<START_PORT+MAX_ATTEMPTS; CHECK_PORT++)); do
  # Check if port is in use
  if ! lsof -i :${CHECK_PORT} &> /dev/null; then
    # Port is available
    PORT=$CHECK_PORT
    echo -e "${GREEN}✓ Port ${PORT} is available${NC}"
    break
  fi
done

if [ -z "$PORT" ]; then
  echo -e "${RED}ERROR: Could not find an available port in range ${START_PORT}-$((START_PORT+MAX_ATTEMPTS-1)). Please free up some ports.${NC}" >&2
  exit 1
fi

echo -e "${GREEN}✓ Using port ${PORT}${NC}"
echo ""

# Create tmux session
tmux new -s "$SESSION_NAME" -d
"$SCRIPT_DIR/configure-tmux-status.sh" "$SESSION_NAME" "$PORT"

# Window 1: main
tmux rename-window -t "$SESSION_NAME":0 main

# Start vim in the first pane (top)
tmux send-keys -t "$SESSION_NAME":0.0 'vim' C-m

# Split horizontally to create bottom pane (33% height)
tmux split-window -v -p 33 -t "$SESSION_NAME":0

# Split the bottom pane vertically to create console (left) and claude (right)
tmux split-window -h -t "$SESSION_NAME":0.1

# The layout is now:
# Pane 0 (top): vim
# Pane 1 (bottom-left): console (shell)
# Pane 2 (bottom-right): claude

# Start claude in the bottom-right pane
tmux send-keys -t "$SESSION_NAME":0.2 'claude --dangerously-skip-permissions' C-m

# Window 2: server
tmux new-window -t "$SESSION_NAME":1
tmux rename-window -t "$SESSION_NAME":1 server

# Start Procfile.dev processes (web server, jobs, etc.)
tmux send-keys -t "$SESSION_NAME":1 "PORT=$PORT bin/dev" C-m

# Select the main window and the vim pane
tmux select-window -t "$SESSION_NAME":0
tmux select-pane -t "$SESSION_NAME":0.0

# Attach to session
tmux attach -t "$SESSION_NAME"
