#!/usr/bin/env bash
# spotify_info.sh — fetch Spotify info + rounded album art (PNG only)
# Saves exactly: title.txt, artist.txt, art.png
# deps: playerctl, curl, jq, ImageMagick (magick)

set -euo pipefail

PLAYER="${1:-spotify,Spicetify}"          # e.g. ./spotify_info.sh com.spotify.Client
OUT_DIR="/tmp/spotify_cache"
mkdir -p "$OUT_DIR"

# ------ settings you can tweak ------
ART_RADIUS=18        # corner radius in *source-image* pixels
ICON_RADIUS=180
# ------------------------------------

# --- Load .env for CLIENT_ID/SECRET ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi
: "${SPOTIFY_CLIENT_ID:?Set SPOTIFY_CLIENT_ID in .env}"
: "${SPOTIFY_CLIENT_SECRET:?Set SPOTIFY_CLIENT_SECRET in .env}"

# --- Token cache ---
TOKEN=""; TOKEN_EXP=0
now() { date +%s; }
get_token() {
  local t exp
  if (( $(now) < TOKEN_EXP )); then echo "$TOKEN"; return 0; fi
  read -r t exp < <(
    curl -s -u "$SPOTIFY_CLIENT_ID:$SPOTIFY_CLIENT_SECRET" \
      -d grant_type=client_credentials \
      https://accounts.spotify.com/api/token \
      | jq -r '"\(.access_token) \(.expires_in)"'
  )
  [[ -z "${t:-}" || "$t" == "null" ]] && { echo "Failed to get Spotify API token" >&2; return 1; }
  TOKEN="$t"; TOKEN_EXP=$(( $(now) + ${exp:-3600} - 60 )); echo "$TOKEN"
}

trim() { sed 's/^[[:space:]]\+//; s/[[:space:]]\+$//' <<<"$1"; }

extract_track_id() {
  local uri id
  uri="$(trim "${1:-}")"; [[ -z "$uri" ]] && return 1
  id="$uri"
  id="${id##*:}"         # mpris urn tail
  id="${id#*/track/}"    # URL to id
  id="${id%%\?*}"        # drop query
  [[ "$id" == *:* ]] && id="${id##*:}"
  [[ -n "$id" ]] && printf '%s\n' "$id"
}

# ---- write rounded PNG (no resize) ----
write_rounded_png() {
  # in: $1 = source JPEG path (temp)
  local src="$1"

  # dimensions (fail-safe copy if identify fails)
  local w h
  if ! w=$(identify -format "%w" "$src") || ! h=$(identify -format "%h" "$src"); then
    cp -f "$src" "$OUT_DIR/art.png"
    cp -f "$src" "$OUT_DIR/icon.png"
    return 0
  fi

  # --- art.png (radius 18) ---
  magick "$src" \
    \( -size "${w}x${h}" xc:none \
       -draw "roundrectangle 0,0 $((w-1)),$((h-1)) $ART_RADIUS,$ART_RADIUS" \) \
    -alpha set -compose DstIn -composite -alpha on PNG32:"$OUT_DIR/art.png.tmp"
  mv -f "$OUT_DIR/art.png.tmp" "$OUT_DIR/art.png"

  # --- icon.png (radius 180) ---
  magick "$src" \
    \( -size "${w}x${h}" xc:none \
       -draw "roundrectangle 0,0 $((w-1)),$((h-1)) $ICON_RADIUS,$ICON_RADIUS" \) \
    -alpha set -compose DstIn -composite -alpha on PNG32:"$OUT_DIR/icon.png.tmp"
  mv -f "$OUT_DIR/icon.png.tmp" "$OUT_DIR/icon.png"
}


fetch_and_write() {
  local id="$1"
  local token json title artists album_art tmpjpg="$OUT_DIR/.art_download.jpg.tmp"

  token="$(get_token)" || return 1
  json="$(curl -s -H "Authorization: Bearer $token" "https://api.spotify.com/v1/tracks/$id")"

  title="$(jq -r '.name // empty' <<<"$json")"
  artists="$(jq -r '[.artists[].name] | join(", ")' <<<"$json")"
  album_art="$(jq -r '.album.images[0].url // empty' <<<"$json")"

  # download jpg to temp, convert to rounded PNG art.png, then delete temp
  if [[ -n "$album_art" ]]; then
    if curl -fsSL --connect-timeout 2 --max-time 4 -o "$tmpjpg" "$album_art"; then
      write_rounded_png "$tmpjpg"
      rm -f "$tmpjpg"
    fi
  fi

  # atomically write text files
  [[ -n "$title"   ]] && { printf '%s\n' "$title"   > "$OUT_DIR/title.txt.tmp";  mv -f "$OUT_DIR/title.txt.tmp"  "$OUT_DIR/title.txt"; }
  [[ -n "$artists" ]] && { printf '%s\n' "$artists" > "$OUT_DIR/artist.txt.tmp"; mv -f "$OUT_DIR/artist.txt.tmp" "$OUT_DIR/artists.txt"; }

  # send signal to waybar
  pkill -RTMIN+10 waybar 2>/dev/null || true
}

# --- Main loop: react on track changes via playerctl ---
LAST_ID=""
playerctl -p "$PLAYER" metadata --format '{{mpris:trackid}}|{{xesam:url}}' --follow |
while IFS='|' read -r tid url; do
  track_id="$(extract_track_id "$tid")"
  [[ -z "$track_id" ]] && track_id="$(extract_track_id "$url" || true)"
  [[ -z "$track_id" ]] && continue

  if [[ "$track_id" != "$LAST_ID" ]]; then
    fetch_and_write "$track_id" || true
    LAST_ID="$track_id"
  fi
done
