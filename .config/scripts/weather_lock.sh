#!/usr/bin/env bash

# Fetch current temperature and condition from YXU (London, Ontario)
weather_raw=$(curl -fsSL "https://wttr.in/YXU?format=%t|%c" 2>/dev/null)

# Split into temp | condition
IFS='|' read -r temp condition <<< "$weather_raw"

# Remove leading '+' from temperatures like '+18°C'
if [[ $temp == +* ]]; then
  temp=${temp#+}
fi

# Hardcode the location label
echo "${temp} ${condition}"

