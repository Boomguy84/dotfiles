#!/usr/bin/env bash
set -euo pipefail

JSON="$HOME/.cache/wal/colors.json"
THEME_DIR="$HOME/.config/btop/themes"
OUT="$THEME_DIR/wal.theme"

mkdir -p "$THEME_DIR"

# make sure colors.json exists
[ -s "$JSON" ] || {
  echo "wal colors.json not found: $JSON" >&2
  exit 0
}

# read palette via jq
bg=$(jq -r '.special.background' "$JSON")
fg=$(jq -r '.special.foreground' "$JSON")

c1=$(jq -r '.colors.color1' "$JSON")
c2=$(jq -r '.colors.color2' "$JSON")
c3=$(jq -r '.colors.color3' "$JSON")
c4=$(jq -r '.colors.color4' "$JSON")
c5=$(jq -r '.colors.color5' "$JSON")
c6=$(jq -r '.colors.color6' "$JSON")
c7=$(jq -r '.colors.color7' "$JSON")
c8=$(jq -r '.colors.color8' "$JSON")

cat >"$OUT" <<EOF
# Auto-generated from Pywal — DO NOT EDIT
# Source: $JSON

theme[main_bg]="$bg"
theme[main_fg]="$fg"
theme[title]="$fg"

theme[hi_fg]="$c3"

theme[selected_bg]="$c1"
theme[selected_fg]="$fg"

theme[inactive_fg]="$c8"
theme[graph_text]="$c4"
theme[meter_bg]="$bg"
theme[proc_misc]="$fg"

theme[cpu_box]="$c3"
theme[mem_box]="$c4"
theme[net_box]="$c5"
theme[proc_box]="$c1"
theme[div_line]="$c1"

# gradients
theme[temp_start]="$c4"
theme[temp_mid]  ="$c5"
theme[temp_end]  ="$c6"

theme[cpu_start] ="$c1"
theme[cpu_mid]   ="$c2"
theme[cpu_end]   ="$c4"

theme[free_start] ="$c1"
theme[free_mid]   ="$c2"
theme[free_end]   ="$c4"

theme[cached_start] ="$c2"
theme[cached_mid]   ="$c4"
theme[cached_end]   ="$c6"

theme[available_start] ="$fg"
theme[available_mid]   ="$c6"
theme[available_end]   ="$c5"

theme[used_start] ="$c1"
theme[used_mid]   ="$c3"
theme[used_end]   ="$c6"

theme[download_start] ="$c2"
theme[download_mid]   ="$c4"
theme[download_end]   ="$c5"

theme[upload_start] ="$c1"
theme[upload_mid]   ="$c2"
theme[upload_end]   ="$c4"

theme[process_start] ="$c1"
theme[process_mid]   ="$c2"
theme[process_end]   ="$c4"

theme[warning]  ="$c5"
theme[critical] ="$c3"
EOF
