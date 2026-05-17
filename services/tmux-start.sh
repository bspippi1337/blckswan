#!/usr/bin/env bash

tmux has-session -t forge-main 2>/dev/null || {
  tmux new-session -d -s forge-main
  tmux send-keys -t forge-main "bash ~/blckswan/forge/tui/live.sh" C-m
}

tmux has-session -t logs 2>/dev/null || {
  tmux new-session -d -s logs
  tmux send-keys -t logs "journalctl -f -n 50" C-m
}
