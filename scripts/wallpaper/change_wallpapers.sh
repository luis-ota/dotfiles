#!/bin/bash

# Define the directory where the wallpapers are stored
WALLPAPER_DIR="$HOME/google-drive/diversos-salvos/wallpapers/"

# Get a random wallpaper for each monitor
WALLPAPER1=$(find "$WALLPAPER_DIR" -type f | shuf -n 1)
WALLPAPER2=$(find "$WALLPAPER_DIR" -type f | shuf -n 1)

# Detect the number of connected screens using xrandr
SCREEN_COUNT=$(xrandr | grep ' connected' | wc -l)

if [ "$SCREEN_COUNT" -eq 1 ]; then
    # If only one screen is connected, set wallpaper on the first screen
    nitrogen --head=0 --set-scaled "$WALLPAPER1"
else
    # If two screens are connected, set wallpaper for both screens
    nitrogen --head=0 --set-scaled "$WALLPAPER1"
    nitrogen --head=1 --set-scaled "$WALLPAPER2"
fi
