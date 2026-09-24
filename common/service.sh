#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in late_start service mode

##########################################################################################
# TL-WN722N v2/v3 guard (Realtek RTL8188EUS, USB ID 0bda:8179)
#
# Ensures the firmware is placed where the kernel can load it and, if the driver
# already probed before the module overlay was visible, re-probes the adapter so
# the firmware actually gets loaded.
#
# Kernel drivers that request this firmware (exact string):
#   - rtl8xxxu (mainline >= 6.3, used by NetHunter):  "rtlwifi/rtl8188eufw.bin"
#   - r8188eu  (staging, kernels <= 6.2):             "rtlwifi/rtl8188eufw.bin"
##########################################################################################

FW_REL=rtlwifi/rtl8188eufw.bin          # path the kernel asks for, relative to /system/etc/firmware
FW_SYS=/system/etc/firmware/$FW_REL     # kernel request_firmware() search path
FW_VEN=/vendor/etc/firmware/$FW_REL     # fallback copy location (also searched)
VID=0bda                                # Realtek
PID=8179                                # RTL8188EUS (TL-WN722N v2/v3)

# NOTE: /system/bin/log is called by full path on purpose; naming this
# function "log" and calling "log" inside it would recurse forever.
log() { /system/bin/log -t nh-wifi-firmware "$1" 2>/dev/null || echo "nh-wifi-firmware: $1"; }

# Find the sysfs dir of the adapter. USB devices do NOT appear as "0bda:8179"
# under /sys/bus/usb/devices; they use port paths like "3-2" with idVendor /
# idProduct files inside, so we scan for the match ourselves.
find_adapter() {
  for d in /sys/bus/usb/devices/*/; do
    [ -f "$d/idVendor" ] || continue
    V=$(cat "$d/idVendor" 2>/dev/null)
    P=$(cat "$d/idProduct" 2>/dev/null)
    if [ "$V" = "$VID" ] && [ "$P" = "$PID" ]; then
      echo "${d%/}"
      return 0
    fi
  done
  return 1
}

# 1) Make sure the firmware is visible in the kernel's search path.
#    request_firmware() never looks inside /data/adb/modules; the module's
#    system/etc overlay is what matters. If the overlay is not mounted for any
#    reason, copy the file into /vendor/etc/firmware as a fallback so the
#    driver still finds it.
ensure_placed() {
  if [ -f "$FW_SYS" ]; then
    log "firmware visible at $FW_SYS"
    return 0
  fi
  MODFW=$(find_modfw) || { log "ERROR: module firmware copy missing"; return 1; }
  log "overlay not visible; falling back to $FW_VEN"
  mkdir -p "$(dirname "$FW_VEN")" 2>/dev/null
  cp "$MODFW" "$FW_VEN" 2>/dev/null \
    && chmod 0644 "$FW_VEN" \
    && chown 0:0 "$FW_VEN" 2>/dev/null \
    && chcon u:object_r:vendor_firmware_file:s0 "$FW_VEN" 2>/dev/null
  if [ -f "$FW_VEN" ]; then
    log "firmware placed at $FW_VEN"
    return 0
  fi
  log "ERROR: could not place firmware in search path"
  return 1
}

# Where is the module's own copy of the firmware?
find_modfw() {
  for base in /data/adb/modules/wirelessFirmware /data/adb/modules_update/wirelessFirmware "$MODDIR"; do
    if [ -f "$base/system/etc/firmware/$FW_REL" ]; then
      echo "$base/system/etc/firmware/$FW_REL"
      return 0
    fi
  done
  return 1
}

# 2) Does the adapter have a network interface? Checked under the adapter's own
#    sysfs interfaces ("3-2:1.0/net/wlanX") so the phone's internal wlan0 never
#    causes a false "already up" result.
adapter_if_up() {
  ADAPTER=$1
  ls -d "$ADAPTER":*/net/* >/dev/null 2>&1
}

# 3) If the adapter is present but has no interface, re-probe it now that
#    the firmware is in place. Several mechanisms, first one that works wins.
reprobe_if_needed() {
  ADAPTER=$(find_adapter) || return 0
  DEVNAME=$(basename "$ADAPTER")

  if adapter_if_up "$ADAPTER"; then
    log "adapter $DEVNAME already bound (interface present)"
    return 0
  fi
  log "adapter $DEVNAME present without interface; re-probing"

  # a) ask the kernel to (re)probe the device: drivers_probe expects the sysfs
  #    device name (e.g. "3-2")
  echo "$DEVNAME" > /sys/bus/usb/drivers_probe 2>/dev/null
  sleep 2
  if adapter_if_up "$ADAPTER"; then log "re-probe succeeded"; return 0; fi

  # b) de-authorize + re-authorize (re-enumerates the device)
  echo 0 > "$ADAPTER/authorized" 2>/dev/null
  sleep 1
  echo 1 > "$ADAPTER/authorized" 2>/dev/null
  sleep 2
  if adapter_if_up "$ADAPTER"; then log "re-authorization succeeded"; return 0; fi

  # c) last resort: unbind/bind whatever driver claimed the device
  DRV=$(basename "$(readlink "$ADAPTER/driver" 2>/dev/null)" 2>/dev/null)
  if [ -n "$DRV" ] && [ -d "/sys/bus/usb/drivers/$DRV" ]; then
    echo "$DEVNAME" > "/sys/bus/usb/drivers/$DRV/unbind" 2>/dev/null
    sleep 1
    echo "$VID $PID" > "/sys/bus/usb/drivers/$DRV/bind" 2>/dev/null
    sleep 2
    if adapter_if_up "$ADAPTER"; then log "driver rebind succeeded"; return 0; fi
  fi

  log "adapter still not up; check kernel driver support (dmesg | grep 8188)"
  return 1
}

# Main guard flow: wait for boot, place firmware, fix adapter state.
# Bounded loop so the script can never hang forever if getprop is missing.
(
  i=0
  while [ "$i" -lt 300 ]; do
    [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && break
    sleep 2
    i=$((i + 1))
  done
  ensure_placed || exit 1
  if ADAPTER=$(find_adapter); then
    reprobe_if_needed
  else
    log "TL-WN722N v2 not plugged in; firmware ready for hot-plug"
  fi
) &
