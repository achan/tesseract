#!/bin/bash

# Shared tmux status bar configuration.
# Usage: configure-tmux-status.sh <session-name> <port>

SESSION_NAME="$1"
PORT="$2"

tmux set -t "$SESSION_NAME" status-left ""
tmux set -t "$SESSION_NAME" status-right "#[fg=colour244]#S:$PORT"
