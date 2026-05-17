#!/data/data/com.termux/files/usr/bin/bash
clear
echo "BLCKSWAN // NODE-42"
echo
echo "[1] ssh forge"
echo "[2] mosh forge"
echo "[3] tmux"
read -rp "select> " x
case "$x" in
  1) ssh forge ;;
  2) mosh forge ;;
  3) tmux ;;
  *) bash ;;
esac
