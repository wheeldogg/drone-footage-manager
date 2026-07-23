#!/bin/bash

# drone-config.sh - Shared configuration for all drone scripts
# Sourced by the other scripts; not meant to be run directly.
#
# Destination precedence:
#   DRONE_DEST env var  ->  <repo>/drone.conf  ->  ~/.drone.conf  ->  ~/Dropbox/DroneFootage

DRONE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRONE_REPO_ROOT="$(dirname "$DRONE_SCRIPT_DIR")"

# Remember any env-var override before the config files can clobber it
_DRONE_DEST_ENV="$DRONE_DEST"
_DRONE_SD_ROOT_ENV="$DRONE_SD_ROOT"
_DRONE_SD_PATH_ENV="$DRONE_SD_PATH"

# Machine-specific overrides (gitignored)
[ -f "$DRONE_REPO_ROOT/drone.conf" ] && source "$DRONE_REPO_ROOT/drone.conf"
[ -f "$HOME/.drone.conf" ] && source "$HOME/.drone.conf"

# Where imported footage lands
DEST_BASE="${_DRONE_DEST_ENV:-${DRONE_DEST:-$HOME/Dropbox/DroneFootage}}"
DROPBOX_BASE="$DEST_BASE"   # back-compat alias for existing references

# SD card layout
SD_ROOT="${_DRONE_SD_ROOT_ENV:-${DRONE_SD_ROOT:-/Volumes/DJI}}"
SD_PATH="${_DRONE_SD_PATH_ENV:-${DRONE_SD_PATH:-$SD_ROOT/DCIM/DJI_001}}"
HYPERLAPSE_PATH="$SD_ROOT/DCIM/HYPERLAPSE"
PANORAMA_PATH="$SD_ROOT/DCIM/PANORAMA"

TEMP_DIR="${DRONE_TEMP:-$HOME/.drone_temp}"
