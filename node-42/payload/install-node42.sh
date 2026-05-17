#!/data/data/com.termux/files/usr/bin/bash

set -e

pkg update -y

pkg install -y \
  openssh \
  mosh \
  tmux \
  git \
  curl \
  wget \
  rsync \
  neofetch \
  btop \
  glow \
  ranger \
  cmatrix \
  termux-api

mkdir -p ~/blckswan

###############################################################################
# COLORS
###############################################################################

mkdir -p ~/.termux

cat > ~/.termux/colors.properties <<COLORS
background=#050505
foreground=#ff6a00
cursor=#ff6a00

color0=#111111
color1=#ff4e00
color2=#ff7b00
color3=#ffaa00
color4=#ff5a00
color5=#ff6a00
color6=#ff8844
color7=#ffaa66
COLORS

###############################################################################
# LOGIN BANNER
###############################################################################

cat > ~/blckswan/banner.txt <<'BANNER'
BLCKSWAN // NODE-42

salvaged systems operational
forge uplink ready
BANNER

###############################################################################
# COCKPIT
###############################################################################

cat > ~/blckswan/cockpit.sh <<'COCKPIT'
#!/data/data/com.termux/files/usr/bin/bash

while true; do

clear

IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"

cat ~/blckswan/banner.txt

echo
echo "STATUS"
echo "==================="

printf "DEVICE......... %s\n" "$(getprop ro.product.model)"
printf "ANDROID........ %s\n" "$(getprop ro.build.version.release)"
printf "IP............. %s\n" "$IP"

echo
echo "ACTIONS"
echo "==================="

echo "[1] mosh forge"
echo "[2] ssh forge"
echo "[3] tmux"
echo "[4] btop"
echo "[5] matrix"
echo "[6] shell"

echo
read -rp "select> " x

case "$x" in
  1) mosh forge ;;
  2) ssh forge ;;
  3) tmux ;;
  4) btop ;;
  5) cmatrix ;;
  6) bash ;;
esac

done
COCKPIT

chmod +x ~/blckswan/cockpit.sh

###############################################################################
# AUTOSTART
###############################################################################

grep -q "blckswan/cockpit.sh" ~/.bashrc || \
echo "bash ~/blckswan/cockpit.sh" >> ~/.bashrc

###############################################################################
# SSH CONFIG
###############################################################################

mkdir -p ~/.ssh

cat > ~/.ssh/config <<SSH
Host forge
    HostName REPLACE_FORGE_IP
    User REPLACE_USER
    ServerAliveInterval 30
    ServerAliveCountMax 3
SSH

###############################################################################
# FINISH
###############################################################################

termux-reload-settings

echo
echo "NODE-42 READY"
echo
echo "edit:"
echo "~/.ssh/config"
echo
echo "replace:"
echo "REPLACE_FORGE_IP"
echo "REPLACE_USER"
echo
