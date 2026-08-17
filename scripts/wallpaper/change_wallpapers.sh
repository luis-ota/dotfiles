#!/bin/bash

# Define the directory where the wallpapers are stored
WALLPAPER_DIR="$HOME/google-drive/diversos-salvos/wallpapers/"

[ -d "$WALLPAPER_DIR" ] || exit 1

# Get random wallpapers for each monitor
WALLPAPERS=($(find "$WALLPAPER_DIR" -type f | shuf -n 2))

# Detect the number of connected screens using xrandr
SCREEN_COUNT=$(xrandr | grep -cw 'connected')

if [ "$SCREEN_COUNT" -le 1 ]; then
    # If only one screen is connected, set wallpaper on the first screen
    [ -n "${WALLPAPERS[0]}" ] && nitrogen --head=0 --set-scaled "${WALLPAPERS[0]}"
else
    # If two screens are connected, set wallpaper for both screens
    [ -n "${WALLPAPERS[0]}" ] && nitrogen --head=0 --set-scaled "${WALLPAPERS[0]}"
    [ -n "${WALLPAPERS[1]}" ] && nitrogen --head=1 --set-scaled "${WALLPAPERS[1]}"
fi