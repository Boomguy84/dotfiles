#!/usr/bin/env bash

# Detect Flatpak vs native
if command -v flatpak >/dev/null && flatpak info com.spotify.Client >/dev/null 2>&1; then
    CMD="flatpak run com.spotify.Client"
    WM_CLASS="Spotify"
else
    CMD="spotify"
    WM_CLASS="Spotify"
fi

# If Spotify is running, focus it; else, launch it
if pgrep -x spotify >/dev/null || pgrep -f com.spotify.Client >/dev/null; then
    # hyprland focus (uses wm_class)
    hyprctl dispatch focuswindow "class:^$WM_CLASS$"
else
    $CMD & disown
fi
