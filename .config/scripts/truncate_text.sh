#!/usr/bin/env bash
# truncate_text.sh — trims text and adds "..." if it's too long
# Usage: truncate_text.sh <file> [maxlen=30]

FILE="$1"
MAXLEN="${2:-30}"

# read first line, strip control chars
LINE="$(tr -d '[:cntrl:]' < "$FILE" | head -n1 || true)"

if [ -z "$LINE" ]; then
  echo
  exit 0
fi

if [ "${#LINE}" -gt "$MAXLEN" ]; then
  echo "${LINE:0:$((MAXLEN-3))}..."
else
  echo "$LINE"
fi
