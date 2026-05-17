#!/usr/bin/env bash
set -euo pipefail

echo "BLCKSWAN PREFLIGHT"
echo "=================="
echo

need() {
 command -v "$1" >/dev/null || {
   echo "[missing] $1"
   exit 1
 }
}

for x in adb heimdall git curl; do
 need "$x"
done

echo "[*] adb devices"
adb devices || true

echo
echo "[*] node identification"

adb shell getprop ro.product.model || true
adb shell getprop ro.product.device || true
adb shell getprop ro.build.version.release || true
adb shell getprop ro.bootloader || true

echo
echo "[ok] preflight complete"
