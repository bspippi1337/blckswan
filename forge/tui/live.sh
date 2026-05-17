#!/usr/bin/env bash

while true; do
  clear

  MEM="$(free -h | awk '/Mem:/ {print $3 "/" $2}')"
  LOAD="$(uptime | awk -F'load average:' '{print $2}')"
  IP="$(hostname -I | awk '{print $1}')"
  UPTIME="$(uptime -p)"

  echo "BLCKSWAN // FORGE"
  echo "================="
  echo
  printf "HOST............. %s\n" "$(hostname)"
  printf "IP............... %s\n" "$IP"
  printf "UPTIME........... %s\n" "$UPTIME"
  printf "LOAD............. %s\n" "$LOAD"
  printf "MEM.............. %s\n" "$MEM"

  echo
  echo "SERVICES"
  echo "-----------------"

  for s in ssh docker fail2ban; do
    printf "%-16s" "$s"
    systemctl is-active "$s" 2>/dev/null || true
  done

  echo
  echo "CONTAINERS"
  echo "-----------------"

  docker ps --format 'table {{.Names}}\t{{.Status}}'

  echo
  echo "SESSIONS"
  echo "-----------------"

  who || true

  sleep 2
done
