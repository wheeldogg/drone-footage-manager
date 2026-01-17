#!/bin/bash

# drone-import-dropbox.sh - Direct import to Dropbox for low storage situations
# Separates videos and photos, uploads to Dropbox immediately

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
TEMP_DIR="$HOME/.drone_temp"  # Small temp directory for processing

# Function to print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Check available space
AVAILABLE_GB=$(df ~ | tail -1 | awk '{print int($4/1024/1024)}')
print_msg $YELLOW "Available space on Mac: ${AVAILABLE_GB}GB"

if [ $AVAILABLE_GB -lt 10 ]; then
    print_msg $RED "Warning: Very low disk space!"
    print_msg $YELLOW "Will process files in small batches"
fi

# Get project name
if [ $# -lt 1 ]; then
    DATE=$(date +%Y-%m-%d)
    PROJECT_NAME="${DATE}_Drone_Flight"
    print_msg $YELLOW "Using default name: $PROJECT_NAME"
else
    PROJECT_NAME="$1"
fi

# Create Dropbox structure
DATE=$(echo "$PROJECT_NAME" | cut -d'_' -f1)
YEAR=$(echo "$DATE" | cut -d'-' -f1)
MONTH=$(echo "$DATE" | cut -d'-' -f2)
MONTH_NAME=$(date -j -f "%m" "$MONTH" +"%m-%B" 2>/dev/null || echo "11-November")
PROJECT_DIR="$DROPBOX_BASE/$YEAR/$MONTH_NAME/$PROJECT_NAME"

print_msg $BLUE "Creating Dropbox project structure..."
mkdir -p "$PROJECT_DIR"/{VIDEO/RAW,VIDEO/SRT,PHOTOS/RAW,PHOTOS/INSTAGRAM,PHOTOS/PANORAMA,METADATA,MUSIC}

# Create small temp directory
mkdir -p "$TEMP_DIR"

# Count files
print_msg $BLUE "\nAnalyzing SD card..."
VIDEO_COUNT=$(find "$SD_PATH" -type f \( -name "*.MP4" -o -name "*.MOV" \) 2>/dev/null | wc -l | tr -d ' ')
PHOTO_COUNT=$(find "$SD_PATH" -type f \( -name "*.JPG" -o -name "*.JPEG" \) 2>/dev/null | wc -l | tr -d ' ')
SRT_COUNT=$(find "$SD_PATH" -type f -name "*.SRT" 2>/dev/null | wc -l | tr -d ' ')

# Check for panorama folders
PANORAMA_COUNT=0
PANORAMA_PATH="/Volumes/DJI/DCIM/PANORAMA"
if [ -d "$PANORAMA_PATH" ]; then
    PANORAMA_COUNT=$(find "$PANORAMA_PATH" -type d -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
fi

print_msg $GREEN "Found:"
print_msg $NC "  Videos: $VIDEO_COUNT files"
print_msg $NC "  Photos: $PHOTO_COUNT files"
print_msg $NC "  Telemetry: $SRT_COUNT files"
if [ $PANORAMA_COUNT -gt 0 ]; then
    print_msg $NC "  Panoramas: $PANORAMA_COUNT sets"
fi

# Process videos in batches to avoid filling disk
print_msg $BLUE "\nProcessing videos (one at a time to save space)..."
VIDEO_NUM=0
for video in "$SD_PATH"/*.MP4 "$SD_PATH"/*.MOV; do
    if [ -f "$video" ]; then
        VIDEO_NUM=$((VIDEO_NUM + 1))
        filename=$(basename "$video")
        print_msg $NC "  [$VIDEO_NUM/$VIDEO_COUNT] Copying: $filename"

        # Copy to temp, then move to Dropbox
        cp "$video" "$TEMP_DIR/"
        mv "$TEMP_DIR/$filename" "$PROJECT_DIR/VIDEO/RAW/"

        # Also copy matching SRT file if exists
        srt_file="${video%.MP4}.SRT"
        if [ -f "$srt_file" ]; then
            cp "$srt_file" "$PROJECT_DIR/VIDEO/SRT/"
        fi
    fi
done

# Process panoramas first
if [ $PANORAMA_COUNT -gt 0 ]; then
    print_msg $BLUE "\nProcessing panoramas..."
    PANO_NUM=0

    # Copy each panorama set
    for pano_set in "$PANORAMA_PATH"/*; do
        if [ -d "$pano_set" ]; then
            PANO_NUM=$((PANO_NUM + 1))
            pano_name=$(basename "$pano_set")
            print_msg $NC "  [$PANO_NUM/$PANORAMA_COUNT] Copying panorama set: $pano_name"

            # Copy panorama set to project
            mkdir -p "$PROJECT_DIR/PHOTOS/PANORAMA/$pano_name"
            cp -r "$pano_set"/* "$PROJECT_DIR/PHOTOS/PANORAMA/$pano_name/" 2>/dev/null || true
        fi
    done
    print_msg $GREEN "  ✓ Copied $PANO_NUM panorama sets"
fi

# Process photos in batches
print_msg $BLUE "\nProcessing photos..."
PHOTO_NUM=0

# Copy regular photos
for photo in "$SD_PATH"/*.JPG "$SD_PATH"/*.JPEG; do
    if [ -f "$photo" ]; then
        PHOTO_NUM=$((PHOTO_NUM + 1))
        if [ $((PHOTO_NUM % 10)) -eq 0 ]; then
            print_msg $NC "  Progress: $PHOTO_NUM/$PHOTO_COUNT photos"
        fi

        filename=$(basename "$photo")
        # Process in small batches
        cp "$photo" "$TEMP_DIR/"
        mv "$TEMP_DIR/$filename" "$PROJECT_DIR/PHOTOS/RAW/"
    fi
done

# Generate file list
print_msg $BLUE "\nGenerating project metadata..."
cat > "$PROJECT_DIR/METADATA/file_list.txt" <<EOF
Project: $PROJECT_NAME
Import Date: $(date)
Source: DJI SD Card

FILE COUNT
----------
Videos: $VIDEO_COUNT
Photos: $PHOTO_COUNT
Panoramas: $PANORAMA_COUNT sets
Telemetry: $SRT_COUNT

VIDEO FILES
-----------
EOF

ls -lh "$PROJECT_DIR/VIDEO/RAW/" >> "$PROJECT_DIR/METADATA/file_list.txt" 2>/dev/null

echo -e "\nPHOTO FILES (first 20)\n-----------" >> "$PROJECT_DIR/METADATA/file_list.txt"
ls "$PROJECT_DIR/PHOTOS/RAW/" | head -20 >> "$PROJECT_DIR/METADATA/file_list.txt"

# Create README
cat > "$PROJECT_DIR/README.txt" <<EOF
# $PROJECT_NAME

Date: $(date +%Y-%m-%d)
Location: [Add location]
Weather: [Add conditions]

## Footage Summary
- Videos: $VIDEO_COUNT files
- Photos: $PHOTO_COUNT files
- Panoramas: $PANORAMA_COUNT sets
- Flight telemetry: $SRT_COUNT files

## Notes
[Add shoot notes here]

## File Organization
- VIDEO/RAW/ - Original video files
- VIDEO/SRT/ - GPS and telemetry data
- PHOTOS/RAW/ - Original photos
- PHOTOS/PANORAMA/ - Panorama sequences

EOF

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Final summary
print_msg $GREEN "\n========================================="
print_msg $GREEN "✓ IMPORT TO DROPBOX COMPLETE!"
print_msg $GREEN "========================================="
print_msg $GREEN "Project: $PROJECT_NAME"
print_msg $GREEN "Location: $PROJECT_DIR"
print_msg $GREEN ""
print_msg $CYAN "Files imported:"
print_msg $NC "  Videos: $VIDEO_COUNT → VIDEO/RAW/"
print_msg $NC "  Photos: $PHOTO_COUNT → PHOTOS/RAW/"
if [ $PANORAMA_COUNT -gt 0 ]; then
    print_msg $NC "  Panoramas: $PANORAMA_COUNT sets → PHOTOS/PANORAMA/"
fi
print_msg $NC "  Telemetry: $SRT_COUNT → VIDEO/SRT/"
print_msg $GREEN ""
print_msg $YELLOW "⚠️  IMPORTANT:"
print_msg $NC "1. Wait for Dropbox to finish syncing (check menu bar icon)"
print_msg $NC "2. After sync completes, you can:"
print_msg $NC "   • Right-click folders → 'Make Available Online-only'"
print_msg $NC "   • This frees up local disk space"
print_msg $NC "3. SD card can be safely formatted after Dropbox sync"
print_msg $GREEN ""
print_msg $BLUE "To check Dropbox sync status:"
if command -v dropbox &> /dev/null; then
    dropbox status
else
    print_msg $NC "Check the Dropbox icon in your menu bar"
fi

# Ask about SD card
echo
read -p "View imported files in Finder? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$PROJECT_DIR"
fi