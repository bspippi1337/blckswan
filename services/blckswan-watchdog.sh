#!/usr/bin/env bash

set -Eeuo pipefail

LOG="$HOME/blckswan/logs/watchdog.log"

echo "[$(date)] watchdog cycle" >> "$LOG"

systemctl is-active ssh >/dev/null || sudo systemctl restart ssh
systemctl is-active docker >/dev/null || sudo systemctl restart docker
systemctl is-active fail2ban >/dev/null || sudo systemctl restart fail2ban

docker ps >/dev/null 2>&1 || sudo systemctl restart docker

df -h / >> "$LOG"

