#!/data/data/com.termux/files/usr/bin/bash

mkdir -p ~/.termux

cat > ~/.termux/colors.properties <<COLORS
background=#050505
foreground=#ff6b1a
cursor=#ff6b1a

color0=#101010
color1=#ff4e00
color2=#ff7a1a
color3=#ff9d42
color4=#cc5a1a
color5=#ff6600
color6=#ff8844
color7=#ffaa66
COLORS

cat > ~/.termux/font.ttf.notice <<NOTICE
Install a chunky monospace font manually.
Suggestions:
- Terminus
- JetBrainsMono Nerd Font
- IBM Plex Mono
NOTICE

termux-reload-settings

echo
echo "BLCKSWAN TERMUX STYLE APPLIED"
