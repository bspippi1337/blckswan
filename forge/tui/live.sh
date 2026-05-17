#!/usr/bin/env bash

while true; do
  clear

  echo "BLCKSWAN // FORGE"
  echo "================="
  echo

  printf "HOST........ %s\n" "$(hostname)"
  printf "UPTIME...... %s\n" "$(uptime -p)"
  printf "LOAD........ %s\n" "$(uptime | awk -F'load average:' '{print $2}')"
  printf "IP.......... %s\n" "$(hostname -I | cut -d" " -f1)"

  echo
  echo "CONTAINERS"
  echo "----------------"

  docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null

  sleep 2
done
