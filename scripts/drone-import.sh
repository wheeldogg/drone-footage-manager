#!/bin/bash

# drone-import.sh - Smart import script for DJI drone footage
# Automatically separates videos and photos into organized folders
# Usage: ./drone-import.sh "ProjectName" [SD_PATH]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
EXTERNAL_DRIVE="/Volumes/astroball"
DRONE_BASE="$EXTERNAL_DRIVE/DroneProjects"
ACTIVE_DIR="$DRONE_BASE/ActiveProjects"
DEFAULT_SD_PATH="/Volumes/DJI/DCIM"

# Function to print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Function to format file size
format_size() {
    local size=$1
    if [ $size -gt 1073741824 ]; then
        echo "$(echo "scale=2; $size / 1073741824" | bc) GB"
    elif [ $size -gt 1048576 ]; then
        echo "$(echo "scale=2; $size / 1048576" | bc) MB"
    else
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    fi
}

# Check if external drive is mounted
if [ ! -d "$EXTERNAL_DRIVE" ]; then
    print_msg $RED "Error: External drive '$EXTERNAL_DRIVE' not found!"
    print_msg $YELLOW "Please connect your external drive and try again."
    exit 1
fi

# Get project name from arguments
if [ $# -lt 1 ]; then
    print_msg $YELLOW "Usage: $0 \"ProjectName\" [SD_PATH]"
    print_msg $YELLOW "Example: $0 \"Coastline_Shoot\""
    print_msg $YELLOW "Example: $0 \"Coastline_Shoot\" \"/Volumes/DJI/DCIM\""
    exit 1
fi

PROJECT_NAME="$1"
SD_PATH="${2:-$DEFAULT_SD_PATH}"
DATE=$(date +%Y-%m-%d)
PROJECT_DIR="$ACTIVE_DIR/${DATE}_${PROJECT_NAME}"

# Check if SD card is mounted
if [ ! -d "$SD_PATH" ]; then
    print_msg $RED "Error: SD card not found at $SD_PATH"
    print_msg $YELLOW "Please insert your DJI SD card and try again."
    print_msg $YELLOW "Or specify the correct path: $0 \"$PROJECT_NAME\" \"/path/to/sd/card\""

    # Try to find DJI volumes
    print_msg $BLUE "\nLooking for DJI volumes..."
    if ls /Volumes/ | grep -i dji > /dev/null 2>&1; then
        print_msg $GREEN "Found potential DJI volumes:"
        ls /Volumes/ | grep -i dji
    fi
    exit 1
fi

# Check if project already exists
if [ -d "$PROJECT_DIR" ]; then
    print_msg $YELLOW "Warning: Project '$PROJECT_NAME' already exists for today."
    read -p "Do you want to overwrite? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_msg $RED "Import cancelled."
        exit 1
    fi
    rm -rf "$PROJECT_DIR"
fi

# Create project structure
print_msg $BLUE "Creating project structure..."
mkdir -p "$PROJECT_DIR"/{VIDEO/{RAW,SRT,EXPORTS},PHOTOS/{RAW,PANORAMA,EDITED},DaVinci,METADATA}

# Count files before import
print_msg $BLUE "\nAnalyzing SD card contents..."
VIDEO_COUNT=$(find "$SD_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | wc -l | tr -d ' ')
PHOTO_COUNT=$(find "$SD_PATH" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.dng" \) 2>/dev/null | wc -l | tr -d ' ')
SRT_COUNT=$(find "$SD_PATH" -type f -iname "*.srt" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_SIZE=$(du -sh "$SD_PATH" 2>/dev/null | cut -f1)

print_msg $GREEN "Found:"
print_msg $GREEN "  Videos: $VIDEO_COUNT files"
print_msg $GREEN "  Photos: $PHOTO_COUNT files"
print_msg $GREEN "  Telemetry: $SRT_COUNT files"
print_msg $GREEN "  Total size: $TOTAL_SIZE"

# Ask for confirmation
echo
read -p "Proceed with import? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_msg $RED "Import cancelled."
    exit 1
fi

# Import videos with progress
if [ $VIDEO_COUNT -gt 0 ]; then
    print_msg $BLUE "\nImporting videos..."
    find "$SD_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" \) -print0 2>/dev/null | while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        print_msg $NC "  Copying: $filename"
        cp "$file" "$PROJECT_DIR/VIDEO/RAW/"
    done
fi

# Import SRT files (telemetry data)
if [ $SRT_COUNT -gt 0 ]; then
    print_msg $BLUE "\nImporting telemetry data..."
    find "$SD_PATH" -type f -iname "*.srt" -print0 2>/dev/null | while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        print_msg $NC "  Copying: $filename"
        cp "$file" "$PROJECT_DIR/VIDEO/SRT/"
    done
fi

# Import photos
if [ $PHOTO_COUNT -gt 0 ]; then
    print_msg $BLUE "\nImporting photos..."
    find "$SD_PATH" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.dng" \) -print0 2>/dev/null | while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        filepath=$(dirname "$file")

        # Check if this is part of a panorama sequence (usually in numbered folders)
        if echo "$filepath" | grep -E "/[0-9]{3}_[0-9]{4}" > /dev/null 2>&1; then
            pano_folder=$(echo "$filepath" | grep -oE "[0-9]{3}_[0-9]{4}")
            print_msg $NC "  Copying panorama: $pano_folder/$filename"
            mkdir -p "$PROJECT_DIR/PHOTOS/PANORAMA/$pano_folder"
            cp "$file" "$PROJECT_DIR/PHOTOS/PANORAMA/$pano_folder/"
        else
            print_msg $NC "  Copying: $filename"
            cp "$file" "$PROJECT_DIR/PHOTOS/RAW/"
        fi
    done
fi

# Generate checksums for verification
print_msg $BLUE "\nGenerating checksums for verification..."
cd "$PROJECT_DIR"
find . -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.dng" -o -iname "*.srt" \) -exec md5 {} \; > METADATA/checksums.md5

# Create metadata file
print_msg $BLUE "Creating project metadata..."
cat > "$PROJECT_DIR/METADATA/project_info.txt" <<EOF
===========================================
Project: $PROJECT_NAME
Date Created: $(date)
Import Date: $DATE
===========================================

IMPORT SUMMARY
--------------
Videos: $VIDEO_COUNT files
Photos: $PHOTO_COUNT files
Telemetry: $SRT_COUNT files
Total Size: $TOTAL_SIZE

Source: $SD_PATH
Destination: $PROJECT_DIR

FILES IMPORTED
--------------
EOF

# Add file listing to metadata
echo -e "\nVIDEO FILES:" >> "$PROJECT_DIR/METADATA/project_info.txt"
ls -la "$PROJECT_DIR/VIDEO/RAW/" 2>/dev/null >> "$PROJECT_DIR/METADATA/project_info.txt" || echo "  No video files" >> "$PROJECT_DIR/METADATA/project_info.txt"

echo -e "\nPHOTO FILES:" >> "$PROJECT_DIR/METADATA/project_info.txt"
ls -la "$PROJECT_DIR/PHOTOS/RAW/" 2>/dev/null >> "$PROJECT_DIR/METADATA/project_info.txt" || echo "  No photo files" >> "$PROJECT_DIR/METADATA/project_info.txt"

echo -e "\nPANORAMA SETS:" >> "$PROJECT_DIR/METADATA/project_info.txt"
ls -la "$PROJECT_DIR/PHOTOS/PANORAMA/" 2>/dev/null >> "$PROJECT_DIR/METADATA/project_info.txt" || echo "  No panorama files" >> "$PROJECT_DIR/METADATA/project_info.txt"

# Create README template for shoot notes
cat > "$PROJECT_DIR/README.txt" <<EOF
# $PROJECT_NAME
Date: $DATE

## Location
[Add location details]

## Weather Conditions
- Temperature:
- Wind:
- Cloud cover:
- Time of day:

## Equipment
- Drone: DJI
- Additional equipment:

## Shots Captured
### Videos
- [ ] Establishing shots
- [ ] Detail shots
- [ ] B-roll
- [ ] Other:

### Photos
- [ ] Landscape
- [ ] Detail
- [ ] Panorama
- [ ] Other:

## Notes
[Add any additional notes about the shoot]

## Post-Production Plan
[Add editing notes or ideas]

EOF

# Final summary
print_msg $GREEN "\n========================================="
print_msg $GREEN "✓ IMPORT COMPLETE!"
print_msg $GREEN "========================================="
print_msg $GREEN "Project: $PROJECT_NAME"
print_msg $GREEN "Location: $PROJECT_DIR"
print_msg $GREEN ""
print_msg $GREEN "Structure created:"
print_msg $BLUE "  VIDEO/"
print_msg $NC "    ├── RAW/      ($VIDEO_COUNT videos)"
print_msg $NC "    ├── SRT/      ($SRT_COUNT telemetry files)"
print_msg $NC "    └── EXPORTS/  (for your renders)"
print_msg $BLUE "  PHOTOS/"
print_msg $NC "    ├── RAW/      ($PHOTO_COUNT photos)"
print_msg $NC "    ├── PANORAMA/ (panorama sequences)"
print_msg $NC "    └── EDITED/   (for processed photos)"
print_msg $BLUE "  DaVinci/        (for project files)"
print_msg $BLUE "  METADATA/       (checksums & logs)"
print_msg $GREEN ""
print_msg $YELLOW "Next steps:"
print_msg $NC "1. Open DaVinci Resolve"
print_msg $NC "2. Create new project in: $PROJECT_DIR/DaVinci/"
print_msg $NC "3. Import media from: $PROJECT_DIR/VIDEO/RAW/"
print_msg $NC "4. Edit README.txt with shoot details"
print_msg $GREEN ""
print_msg $YELLOW "SD Card can be safely ejected after verifying files."

# Ask if user wants to eject SD card
echo
read -p "Eject SD card now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    diskutil eject "$SD_PATH" 2>/dev/null && print_msg $GREEN "✓ SD card ejected safely" || print_msg $RED "Could not eject SD card. Please eject manually."
fi