#!/usr/bin/env bash

tmux has-session -t forge-main 2>/dev/null || {
  tmux new-session -d -s forge-main
  tmux send-keys -t forge-main "cd ~/blckswan && bash forge/status.sh" C-m
}

tmux has-session -t salvage 2>/dev/null || {
  tmux new-session -d -s salvage
}

tmux has-session -t watchtower 2>/dev/null || {
  tmux new-session -d -s watchtower
  tmux send-keys -t watchtower "watch -n 5 docker ps" C-m
}
