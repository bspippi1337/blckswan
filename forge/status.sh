#!/usr/bin/env bash
clear
echo "BLCKSWAN // FORGE STATUS"
echo "========================"
hostnamectl | sed -n '1,8p'
echo
uptime
echo
free -h
echo
df -h /
echo
systemctl is-active ssh docker fail2ban avahi-daemon 2>/dev/null || true
