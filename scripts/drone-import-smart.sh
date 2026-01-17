#!/bin/bash

# drone-import-smart.sh - Smart import that auto-detects dates from files
# Automatically organizes by actual file dates, not project name
# Usage: ./drone-import-smart.sh [custom_name]

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
SD_PATH="/Volumes/DJI/DCIM/DJI_001"
TEMP_DIR="$HOME/.drone_temp"

# Function to print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Check if SD card is mounted
if [ ! -d "/Volumes/DJI" ]; then
    print_msg $RED "Error: DJI SD card not found!"
    exit 1
fi

# Analyze dates on SD card
print_msg $CYAN "========================================="
print_msg $CYAN "Analyzing SD Card Contents"
print_msg $CYAN "========================================="

# Get unique dates from files
print_msg $BLUE "\nDetecting dates from files..."
DATES=$(find "$SD_PATH" -name "DJI_*.MP4" -o -name "DJI_*.JPG" 2>/dev/null | \
    sed 's/.*DJI_\([0-9]\{8\}\).*/\1/' | sort -u)

if [ -z "$DATES" ]; then
    print_msg $RED "No DJI files found on SD card!"
    exit 1
fi

# Count dates
DATE_COUNT=$(echo "$DATES" | wc -l | tr -d ' ')

print_msg $GREEN "\nFound footage from $DATE_COUNT date(s):"
for date in $DATES; do
    year=${date:0:4}
    month=${date:4:2}
    day=${date:6:2}
    file_count=$(find "$SD_PATH" -name "*${date}*" 2>/dev/null | wc -l | tr -d ' ')
    print_msg $NC "  $year-$month-$day: $file_count files"
done

# Decide on import strategy
if [ $DATE_COUNT -eq 1 ]; then
    # Single date - use that date
    SINGLE_DATE=$DATES
    year=${SINGLE_DATE:0:4}
    month=${SINGLE_DATE:4:2}
    day=${SINGLE_DATE:6:2}
    DEFAULT_NAME="${year}-${month}-${day}_Drone_Footage"
    print_msg $GREEN "\nSingle date detected: $DEFAULT_NAME"
else
    # Multiple dates - use date range
    FIRST_DATE=$(echo "$DATES" | head -1)
    LAST_DATE=$(echo "$DATES" | tail -1)

    first_year=${FIRST_DATE:0:4}
    first_month=${FIRST_DATE:4:2}
    first_day=${FIRST_DATE:6:2}

    last_year=${LAST_DATE:0:4}
    last_month=${LAST_DATE:4:2}
    last_day=${LAST_DATE:6:2}

    DEFAULT_NAME="${first_year}-${first_month}-${first_day}_to_${last_year}-${last_month}-${last_day}_Drone_Footage"
    print_msg $YELLOW "\nMultiple dates detected!"
    print_msg $NC "Range: ${first_year}-${first_month}-${first_day} to ${last_year}-${last_month}-${last_day}"
fi

# Ask user for confirmation or custom name
echo ""
print_msg $YELLOW "Import options:"
print_msg $NC "1) Use auto-detected name: $DEFAULT_NAME"
print_msg $NC "2) Import each date separately"
print_msg $NC "3) Enter custom name"
echo ""
read -p "Choose option [1-3]: " -n 1 -r
echo ""

case $REPLY in
    2)
        # Import each date separately
        print_msg $BLUE "\nImporting each date separately..."
        for date in $DATES; do
            year=${date:0:4}
            month=${date:4:2}
            day=${date:6:2}
            month_name=$(date -j -f "%m" "$month" +"%m-%B" 2>/dev/null || echo "${month}-Month")

            PROJECT_NAME="${year}-${month}-${day}_Drone_Footage"
            PROJECT_DIR="$DROPBOX_BASE/$year/$month_name/$PROJECT_NAME"

            print_msg $CYAN "\n--- Importing $PROJECT_NAME ---"
            mkdir -p "$PROJECT_DIR"/{VIDEO/RAW,VIDEO/SRT,PHOTOS/RAW,PHOTOS/INSTAGRAM,PHOTOS/PANORAMA,METADATA,MUSIC}

            # Count files for this date
            video_count=$(find "$SD_PATH" -name "*${date}*.MP4" 2>/dev/null | wc -l | tr -d ' ')
            photo_count=$(find "$SD_PATH" -name "*${date}*.JPG" 2>/dev/null | wc -l | tr -d ' ')
            srt_count=$(find "$SD_PATH" -name "*${date}*.SRT" 2>/dev/null | wc -l | tr -d ' ')

            print_msg $NC "  Videos: $video_count"
            print_msg $NC "  Photos: $photo_count"
            print_msg $NC "  Telemetry: $srt_count"

            # Copy videos
            if [ $video_count -gt 0 ]; then
                print_msg $BLUE "  Copying videos..."
                find "$SD_PATH" -name "*${date}*.MP4" -exec cp {} "$PROJECT_DIR/VIDEO/RAW/" \;
            fi

            # Copy photos
            if [ $photo_count -gt 0 ]; then
                print_msg $BLUE "  Copying photos..."
                find "$SD_PATH" -name "*${date}*.JPG" -exec cp {} "$PROJECT_DIR/PHOTOS/RAW/" \;
            fi

            # Copy SRT files
            if [ $srt_count -gt 0 ]; then
                print_msg $BLUE "  Copying telemetry..."
                find "$SD_PATH" -name "*${date}*.SRT" -exec cp {} "$PROJECT_DIR/VIDEO/SRT/" \;
            fi

            print_msg $GREEN "  ✓ Imported to: $PROJECT_DIR"
        done

        # Handle panoramas (they don't have dates in names)
        if [ -d "/Volumes/DJI/DCIM/PANORAMA" ]; then
            print_msg $YELLOW "\nFound panorama folder - adding to most recent date"
            last_project="$DROPBOX_BASE/$year/$month_name/$PROJECT_NAME"
            cp -r /Volumes/DJI/DCIM/PANORAMA/* "$last_project/PHOTOS/PANORAMA/" 2>/dev/null || true
        fi

        print_msg $GREEN "\n✓ All dates imported separately!"
        ;;

    3)
        # Custom name
        echo ""
        read -p "Enter custom project name: " CUSTOM_NAME
        PROJECT_NAME="${CUSTOM_NAME:-$DEFAULT_NAME}"

        # Use first date for folder structure
        FIRST_DATE=$(echo "$DATES" | head -1)
        year=${FIRST_DATE:0:4}
        month=${FIRST_DATE:4:2}
        month_name=$(date -j -f "%m" "$month" +"%m-%B" 2>/dev/null || echo "${month}-Month")

        PROJECT_DIR="$DROPBOX_BASE/$year/$month_name/$PROJECT_NAME"

        print_msg $BLUE "\nImporting all files to: $PROJECT_NAME"
        exec ~/Documents/workspace/projects/drone-footage-manager/scripts/drone-import-dropbox.sh "$PROJECT_NAME"
        ;;

    *)
        # Use auto-detected name
        PROJECT_NAME="$DEFAULT_NAME"

        # Use first date for folder structure
        FIRST_DATE=$(echo "$DATES" | head -1)
        year=${FIRST_DATE:0:4}
        month=${FIRST_DATE:4:2}

        print_msg $BLUE "\nImporting all files to: $PROJECT_NAME"
        exec ~/Documents/workspace/projects/drone-footage-manager/scripts/drone-import-dropbox.sh "$PROJECT_NAME"
        ;;
esac

print_msg $GREEN "\n========================================="
print_msg $GREEN "✓ IMPORT COMPLETE!"
print_msg $GREEN "========================================="
print_msg $YELLOW "\nNext steps:"
print_msg $NC "1. Wait for Dropbox to sync"
print_msg $NC "2. Right-click folders → 'Make Available Online-only'"
print_msg $NC "3. SD card can be safely formatted"