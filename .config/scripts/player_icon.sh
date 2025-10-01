#!/usr/bin/env bash

PLAYER="${1:-spotify}" # default to 'spotify', or pass e.g. com.spotify.Client

# Get status, suppress errors if player not available
status=$(playerctl -p "$PLAYER" status 2>/dev/null)

case "$status" in
Playing) echo "" ;; # show pause icon when playing
Paused) echo "" ;;  # show play icon when paused
Stopped) echo "" ;; # show play icon when stopped
*) echo "" ;;       # nothing if no player
esac
