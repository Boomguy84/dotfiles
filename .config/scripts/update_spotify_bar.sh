#!/usr/bin/env bash
set -euo pipefail

TITLE_FILE=/tmp/spotify_cache/title.txt
ARTISTS_FILE=/tmp/spotify_cache/artists.txt
MAXLEN=40

truncate() {
  local text="$1"
  if (( ${#text} > MAXLEN )); then
    echo "${text:0:MAXLEN}…"
  else
    echo "$text"
  fi
}

title=$( [ -f "$TITLE_FILE" ] && head -n1 "$TITLE_FILE" || echo "" )
artists=$( [ -f "$ARTISTS_FILE" ] && head -n1 "$ARTISTS_FILE" || echo "" )

short_title=$(truncate "$title")
short_artists=$(truncate "$artists")

if [[ -n "$short_title$short_artists" ]]; then
  echo "$short_title — $short_artists"
else
  echo ""
fi
