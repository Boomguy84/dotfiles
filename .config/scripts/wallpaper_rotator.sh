#!/usr/bin/env bash
set -Eeuo pipefail

# --- config ---
INTERVAL_MIN=60 # change cadence here
THEMER="$HOME/.config/scripts/wallpaper_theming.sh"
RUNLOCK="$HOME/.cache/wallrotate.run.lock" # per-iteration lock (soft)

# --- prep ---
# minimal GUI/session env so it works outside a terminal
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# ensure swww daemon (harmless if already running)
pgrep -x swww-daemon >/dev/null 2>&1 || swww-daemon >/dev/null 2>&1 &

while :; do
  start_ts=$(date +%s)

  # Per-iteration soft lock: only one theming run at a time.
  # If another process is in the middle of a run (e.g., Waybar click), skip gracefully.
  {
    exec 9>"$RUNLOCK"
    if flock -n 9; then
      if [[ -x "$THEMER" ]]; then
        "$THEMER" || true
      fi
      flock -u 9 || true
    fi
  } 2>/dev/null

  # Sleep the remaining interval (never less than 5s)
  took=$(($(date +%s) - start_ts))
  nap=$((INTERVAL_MIN * 60 - took))
  ((nap < 5)) && nap=5
  sleep "$nap"
done
