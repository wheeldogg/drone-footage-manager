#!/bin/bash

# fix-mixed-dates.sh - Reorganize mixed date files into proper date folders
# This fixes the bug where Nov 9 and Nov 10 files were mixed together

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DROPBOX_BASE="$HOME/Dropbox/DroneFootage"
MIXED_FOLDER="$DROPBOX_BASE/2025/11-November/2025-11-09_Drone_Footage"

print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

print_msg $CYAN "========================================="
print_msg $CYAN "Fixing Mixed Date Files"
print_msg $CYAN "========================================="

# Check if the mixed folder exists
if [ ! -d "$MIXED_FOLDER" ]; then
    print_msg $RED "Folder not found: $MIXED_FOLDER"
    exit 1
fi

# Analyze current situation
print_msg $BLUE "\nAnalyzing current folder..."
NOV9_COUNT=$(find "$MIXED_FOLDER" -name "*20251109*" -type f | wc -l | tr -d ' ')
NOV10_COUNT=$(find "$MIXED_FOLDER" -name "*20251110*" -type f | wc -l | tr -d ' ')

print_msg $NC "Found:"
print_msg $NC "  Nov 9 files: $NOV9_COUNT"
print_msg $NC "  Nov 10 files: $NOV10_COUNT"

if [ $NOV10_COUNT -eq 0 ]; then
    print_msg $GREEN "\nNo Nov 10 files found. Folder is already correct!"
    exit 0
fi

# Ask user what to do
echo ""
print_msg $YELLOW "How would you like to reorganize?"
print_msg $NC "1) Move Nov 10 files to new folder: 2025-11-10_Drone_Footage"
print_msg $NC "2) Keep everything in current folder (rename to show both dates)"
print_msg $NC "3) Cancel"
echo ""
read -p "Choose option [1-3]: " -n 1 -r
echo ""

case $REPLY in
    1)
        # Create new folder for Nov 10
        NOV10_FOLDER="$DROPBOX_BASE/2025/11-November/2025-11-10_Drone_Footage"

        print_msg $BLUE "\nCreating folder for Nov 10 files..."
        mkdir -p "$NOV10_FOLDER"/{VIDEO/RAW,VIDEO/SRT,PHOTOS/RAW,PHOTOS/PANORAMA,METADATA}

        # Move Nov 10 videos
        print_msg $BLUE "Moving Nov 10 videos..."
        find "$MIXED_FOLDER/VIDEO/RAW" -name "*20251110*.MP4" -exec mv {} "$NOV10_FOLDER/VIDEO/RAW/" \; 2>/dev/null || true

        # Move Nov 10 photos
        print_msg $BLUE "Moving Nov 10 photos..."
        find "$MIXED_FOLDER/PHOTOS/RAW" -name "*20251110*.JPG" -exec mv {} "$NOV10_FOLDER/PHOTOS/RAW/" \; 2>/dev/null || true

        # Move Nov 10 SRT files
        print_msg $BLUE "Moving Nov 10 telemetry..."
        find "$MIXED_FOLDER/VIDEO/SRT" -name "*20251110*.SRT" -exec mv {} "$NOV10_FOLDER/VIDEO/SRT/" \; 2>/dev/null || true

        # Move panorama (usually from latest date)
        if [ -d "$MIXED_FOLDER/PHOTOS/PANORAMA/001_0057" ]; then
            print_msg $BLUE "Moving panorama to Nov 10 folder..."
            mv "$MIXED_FOLDER/PHOTOS/PANORAMA/001_0057" "$NOV10_FOLDER/PHOTOS/PANORAMA/" 2>/dev/null || true
        fi

        # Create metadata for Nov 10
        cat > "$NOV10_FOLDER/METADATA/file_list.txt" <<EOF
Project: Nov 10 Drone Footage
Separated from mixed folder on: $(date)

Files moved from: $MIXED_FOLDER
Files in this folder: Nov 10, 2025
EOF

        # Update metadata for Nov 9
        cat > "$MIXED_FOLDER/METADATA/separation_note.txt" <<EOF
Note: Nov 10 files were separated on $(date)
Nov 10 files moved to: $NOV10_FOLDER
This folder now contains only Nov 9, 2025 files
EOF

        # Verify
        print_msg $GREEN "\n✓ Files separated!"
        print_msg $CYAN "\nNew folder structure:"

        NOV9_REMAINING=$(find "$MIXED_FOLDER" -name "*20251109*" -type f | wc -l | tr -d ' ')
        NOV10_MOVED=$(find "$NOV10_FOLDER" -name "*20251110*" -type f | wc -l | tr -d ' ')

        print_msg $NC "  2025-11-09_Drone_Footage: $NOV9_REMAINING files (Nov 9 only)"
        print_msg $NC "  2025-11-10_Drone_Footage: $NOV10_MOVED files (Nov 10 only)"
        ;;

    2)
        # Rename folder to show both dates
        NEW_NAME="2025-11-09_to_11-10_Drone_Footage"
        NEW_PATH="$DROPBOX_BASE/2025/11-November/$NEW_NAME"

        print_msg $BLUE "\nRenaming folder to: $NEW_NAME"
        mv "$MIXED_FOLDER" "$NEW_PATH"

        # Update metadata
        cat > "$NEW_PATH/METADATA/date_info.txt" <<EOF
Project contains footage from multiple dates:
- Nov 9, 2025: $NOV9_COUNT files
- Nov 10, 2025: $NOV10_COUNT files
Renamed on: $(date)
EOF

        print_msg $GREEN "✓ Folder renamed to reflect both dates!"
        ;;

    3)
        print_msg $YELLOW "Cancelled. No changes made."
        exit 0
        ;;

    *)
        print_msg $RED "Invalid option. No changes made."
        exit 1
        ;;
esac

print_msg $GREEN "\n========================================="
print_msg $GREEN "✓ FIX COMPLETE!"
print_msg $GREEN "========================================="