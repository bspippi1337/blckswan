#!/usr/bin/env bash

while true; do

clear

RED="\033[1;31m"
DIM="\033[2m"
NC="\033[0m"

CPU="$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ //')"
TEMP="$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n1)"
MEM="$(free -h | awk '/Mem:/ {print $3 " / " $2}')"
UP="$(uptime -p)"
LOAD="$(uptime | awk -F'load average:' '{print $2}')"
IP="$(hostname -I | awk '{print $1}')"

if [ -n "$TEMP" ]; then
  TEMP="$((TEMP/1000))C"
else
  TEMP="unknown"
fi

printf "$RED"

cat << "BANNER"
██████╗ ██╗      ██████╗██╗  ██╗███████╗██╗    ██╗ █████╗ ███╗   ██╗
██╔══██╗██║     ██╔════╝██║ ██╔╝██╔════╝██║    ██║██╔══██╗████╗  ██║
██████╔╝██║     ██║     █████╔╝ ███████╗██║ █╗ ██║███████║██╔██╗ ██║
██╔══██╗██║     ██║     ██╔═██╗ ╚════██║██║███╗██║██╔══██║██║╚██╗██║
██████╔╝███████╗╚██████╗██║  ██╗███████║╚███╔███╔╝██║  ██║██║ ╚████║
╚═════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═══╝

                        FORGE // SALVAGED SYSTEMS
BANNER

printf "$NC\n"

echo "NODE STATUS"
echo "=================================================="
printf "HOST................ %s\n" "$(hostname)"
printf "IP ADDRESS.......... %s\n" "$IP"
printf "UPTIME.............. %s\n" "$UP"
printf "LOAD................ %s\n" "$LOAD"
printf "MEMORY.............. %s\n" "$MEM"
printf "CORE TEMP........... %s\n" "$TEMP"

echo
echo "SERVICES"
echo "=================================================="

for s in ssh docker fail2ban; do
  if systemctl is-active "$s" >/dev/null 2>&1; then
    printf "%-20s ONLINE\n" "$s"
  else
    printf "%-20s OFFLINE\n" "$s"
  fi
done

echo
echo "CONTAINERS"
echo "=================================================="

docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null

echo
echo "REMOTE ACCESS"
echo "=================================================="

printf "SSH................ ssh %s@%s\n" "$USER" "$IP"
printf "MOSH............... mosh %s@%s\n" "$USER" "$IP"

echo
echo "PHILOSOPHY"
echo "=================================================="
echo "small tools // sharp tools // no telemetry"

sleep 3

done
