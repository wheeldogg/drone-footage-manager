#!/bin/bash

# drone-cleanup-sd.sh - Clean up old files from SD card
# Safely removes files older than a specified date (after verifying backup)
# Usage: ./drone-cleanup-sd.sh [YYYYMMDD]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SD_PATH="/Volumes/DJI/DCIM/DJI_001"
PANORAMA_PATH="/Volumes/DJI/DCIM/PANORAMA"
DROPBOX_BASE="$HOME/Dropbox/DroneFootage"

# Function to print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Check if SD card is mounted
if [ ! -d "/Volumes/DJI" ]; then
    print_msg $RED "Error: DJI SD card not found!"
    print_msg $YELLOW "Please insert your SD card and try again."
    exit 1
fi

# Get date filter
if [ $# -lt 1 ]; then
    print_msg $YELLOW "Delete files by date"
    print_msg $YELLOW "Usage: $0 YYYYMMDD"
    echo ""
    print_msg $BLUE "Files on SD card by date:"
    echo ""

    # Show dates available
    find "$SD_PATH" -name "DJI_*.MP4" -o -name "DJI_*.JPG" 2>/dev/null | \
        sed 's/.*DJI_\([0-9]\{8\}\).*/\1/' | sort -u | \
        while read date; do
            year=${date:0:4}
            month=${date:4:2}
            day=${date:6:2}
            count=$(find "$SD_PATH" -name "*${date}*" 2>/dev/null | wc -l | tr -d ' ')
            echo "  $year-$month-$day (${date}): $count files"
        done

    echo ""
    print_msg $YELLOW "Example: $0 20251109  (deletes all files from Nov 9, 2025)"
    exit 0
fi

DELETE_DATE="$1"
print_msg $CYAN "\n========================================="
print_msg $CYAN "SD Card Cleanup - Date: $DELETE_DATE"
print_msg $CYAN "========================================="

# Count files to be deleted
print_msg $BLUE "\nAnalyzing files from $DELETE_DATE..."
VIDEO_COUNT=$(find "$SD_PATH" -name "*${DELETE_DATE}*.MP4" -o -name "*${DELETE_DATE}*.MOV" 2>/dev/null | grep -v "^\._" | wc -l | tr -d ' ')
PHOTO_COUNT=$(find "$SD_PATH" -name "*${DELETE_DATE}*.JPG" 2>/dev/null | wc -l | tr -d ' ')
SRT_COUNT=$(find "$SD_PATH" -name "*${DELETE_DATE}*.SRT" 2>/dev/null | wc -l | tr -d ' ')

# Check panoramas
PANO_COUNT=0
if [ -d "$PANORAMA_PATH" ]; then
    PANO_COUNT=$(find "$PANORAMA_PATH" -type d -name "*${DELETE_DATE}*" 2>/dev/null | wc -l | tr -d ' ')
fi

print_msg $YELLOW "Files to delete:"
print_msg $NC "  Videos: $VIDEO_COUNT"
print_msg $NC "  Photos: $PHOTO_COUNT"
print_msg $NC "  Panoramas: $PANO_COUNT sets"
print_msg $NC "  Telemetry: $SRT_COUNT"

if [ $VIDEO_COUNT -eq 0 ] && [ $PHOTO_COUNT -eq 0 ] && [ $PANO_COUNT -eq 0 ]; then
    print_msg $GREEN "\nNo files found for date $DELETE_DATE"
    exit 0
fi

# Check if files are in Dropbox
print_msg $BLUE "\nVerifying backup in Dropbox..."
YEAR=${DELETE_DATE:0:4}
BACKED_UP=false

for project in "$DROPBOX_BASE/$YEAR"/*/*; do
    if [ -d "$project" ]; then
        if find "$project" -name "*${DELETE_DATE}*" 2>/dev/null | grep -q .; then
            print_msg $GREEN "  ✓ Found backup in: $(basename "$project")"
            BACKED_UP=true
        fi
    fi
done

if [ "$BACKED_UP" = false ]; then
    print_msg $RED "\n⚠️  WARNING: No backup found in Dropbox!"
    print_msg $YELLOW "It's recommended to import files to Dropbox before deleting."
    echo ""
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_msg $RED "Cleanup cancelled."
        exit 1
    fi
fi

# Calculate space to be freed
SPACE_TO_FREE=$(du -ch "$SD_PATH"/*${DELETE_DATE}* 2>/dev/null | tail -1 | cut -f1)

print_msg $YELLOW "\nSpace to be freed: $SPACE_TO_FREE"

# Confirm deletion
echo ""
print_msg $RED "⚠️  This will permanently delete files from SD card!"
read -p "Proceed with deletion? (y/n): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_msg $RED "Cleanup cancelled."
    exit 1
fi

# Delete files
print_msg $BLUE "\nDeleting files..."

# Delete videos
if [ $VIDEO_COUNT -gt 0 ]; then
    print_msg $NC "  Deleting videos..."
    find "$SD_PATH" -name "*${DELETE_DATE}*.MP4" -type f -delete 2>/dev/null || true
    find "$SD_PATH" -name "*${DELETE_DATE}*.MOV" -type f -delete 2>/dev/null || true
fi

# Delete photos
if [ $PHOTO_COUNT -gt 0 ]; then
    print_msg $NC "  Deleting photos..."
    find "$SD_PATH" -name "*${DELETE_DATE}*.JPG" -type f -delete 2>/dev/null || true
    find "$SD_PATH" -name "*${DELETE_DATE}*.JPEG" -type f -delete 2>/dev/null || true
fi

# Delete telemetry
if [ $SRT_COUNT -gt 0 ]; then
    print_msg $NC "  Deleting telemetry..."
    find "$SD_PATH" -name "*${DELETE_DATE}*.SRT" -type f -delete 2>/dev/null || true
fi

# Delete panoramas
if [ $PANO_COUNT -gt 0 ]; then
    print_msg $NC "  Deleting panoramas..."
    find "$PANORAMA_PATH" -type d -name "*${DELETE_DATE}*" -exec rm -rf {} + 2>/dev/null || true
fi

# Delete metadata files (._)
find "$SD_PATH" -name "._*${DELETE_DATE}*" -type f -delete 2>/dev/null || true

# Check remaining space
NEW_SPACE=$(df -h /Volumes/DJI | tail -1 | awk '{print $4}')

print_msg $GREEN "\n========================================="
print_msg $GREEN "✓ CLEANUP COMPLETE!"
print_msg $GREEN "========================================="
print_msg $GREEN "Deleted files from: $DELETE_DATE"
print_msg $GREEN "Available space on SD: $NEW_SPACE"
print_msg $GREEN ""
print_msg $BLUE "Remaining files on SD card:"
echo ""

# Show remaining files by date
find "$SD_PATH" -name "DJI_*.MP4" -o -name "DJI_*.JPG" 2>/dev/null | \
    sed 's/.*DJI_\([0-9]\{8\}\).*/\1/' | sort -u | \
    while read date; do
        year=${date:0:4}
        month=${date:4:2}
        day=${date:6:2}
        count=$(find "$SD_PATH" -name "*${date}*" 2>/dev/null | wc -l | tr -d ' ')
        print_msg $NC "  $year-$month-$day: $count files"
    done

print_msg $GREEN "\nSD card is ready for new flights! 🚁"