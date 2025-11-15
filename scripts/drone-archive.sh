#!/bin/bash

# drone-archive.sh - Archive completed drone projects
# Moves projects to RecentlyCompleted, uploads finals to Dropbox
# Optionally compresses video for long-term storage
# Usage: ./drone-archive.sh "ProjectPath" [--compress]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
EXTERNAL_DRIVE="/Volumes/astroball"
DRONE_BASE="$EXTERNAL_DRIVE/DroneProjects"
ACTIVE_DIR="$DRONE_BASE/ActiveProjects"
COMPLETED_DIR="$DRONE_BASE/RecentlyCompleted"
ARCHIVE_DIR="$DRONE_BASE/Archive"
DROPBOX_BASE="$HOME/Dropbox/DroneFootage"
CLEANUP_LOG="$DRONE_BASE/cleanup_schedule.txt"

# Function to print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Function to format file size
format_size() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    else
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    fi
}

# Check arguments
if [ $# -lt 1 ]; then
    print_msg $YELLOW "Usage: $0 \"ProjectPath\" [options]"
    print_msg $YELLOW "Options:"
    print_msg $NC "  --compress    Compress videos with HEVC before archiving"
    print_msg $NC "  --photos-only Keep only selected photos"
    print_msg $NC "  --keep-raw    Keep RAW footage in Dropbox (as online-only)"
    echo
    print_msg $YELLOW "Example: $0 \"$ACTIVE_DIR/2025-11-10_Coastline_Shoot\""
    print_msg $YELLOW "Example: $0 \"2025-11-10_Coastline_Shoot\" --compress"
    exit 1
fi

# Parse arguments
PROJECT_PATH="$1"
COMPRESS_VIDEO=false
PHOTOS_ONLY=false
KEEP_RAW=false

for arg in "${@:2}"; do
    case $arg in
        --compress)
            COMPRESS_VIDEO=true
            ;;
        --photos-only)
            PHOTOS_ONLY=true
            ;;
        --keep-raw)
            KEEP_RAW=true
            ;;
    esac
done

# If only project name given, build full path
if [[ ! "$PROJECT_PATH" == /* ]]; then
    if [ -d "$ACTIVE_DIR/$PROJECT_PATH" ]; then
        PROJECT_PATH="$ACTIVE_DIR/$PROJECT_PATH"
    elif [ -d "$COMPLETED_DIR/$PROJECT_PATH" ]; then
        PROJECT_PATH="$COMPLETED_DIR/$PROJECT_PATH"
    else
        print_msg $RED "Error: Project not found in Active or Completed directories"
        print_msg $YELLOW "Available active projects:"
        ls "$ACTIVE_DIR" 2>/dev/null || echo "  None"
        exit 1
    fi
fi

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
    print_msg $RED "Error: Project not found at $PROJECT_PATH"
    exit 1
fi

PROJECT_NAME=$(basename "$PROJECT_PATH")
print_msg $CYAN "\n========================================="
print_msg $CYAN "Archiving Project: $PROJECT_NAME"
print_msg $CYAN "========================================="

# Analyze project
print_msg $BLUE "\nAnalyzing project contents..."
VIDEO_COUNT=$(find "$PROJECT_PATH/VIDEO/RAW" -type f \( -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | wc -l | tr -d ' ')
PHOTO_COUNT=$(find "$PROJECT_PATH/PHOTOS/RAW" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) 2>/dev/null | wc -l | tr -d ' ')
EXPORT_COUNT=$(find "$PROJECT_PATH/VIDEO/EXPORTS" -type f 2>/dev/null | wc -l | tr -d ' ')
RAW_SIZE=$(du -sh "$PROJECT_PATH/VIDEO/RAW" 2>/dev/null | cut -f1 || echo "0")
TOTAL_SIZE=$(du -sh "$PROJECT_PATH" 2>/dev/null | cut -f1)

print_msg $GREEN "Project Summary:"
print_msg $NC "  RAW Videos: $VIDEO_COUNT files ($RAW_SIZE)"
print_msg $NC "  Photos: $PHOTO_COUNT files"
print_msg $NC "  Exports: $EXPORT_COUNT files"
print_msg $NC "  Total Size: $TOTAL_SIZE"

# Check for exports
if [ $EXPORT_COUNT -eq 0 ]; then
    print_msg $YELLOW "\nWarning: No exports found in VIDEO/EXPORTS/"
    read -p "Continue without exports? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_msg $RED "Archive cancelled."
        exit 1
    fi
fi

# Show archive plan
print_msg $BLUE "\nArchive Plan:"
if [ "$COMPRESS_VIDEO" = true ]; then
    print_msg $NC "  • Compress RAW videos to HEVC (50% size reduction)"
fi
if [ "$KEEP_RAW" = true ]; then
    print_msg $NC "  • Upload RAW footage to Dropbox (will be online-only)"
else
    print_msg $NC "  • Keep only final exports in Dropbox"
fi
if [ "$PHOTOS_ONLY" = false ]; then
    print_msg $NC "  • Include all photos"
else
    print_msg $NC "  • Include only selected photos"
fi
print_msg $NC "  • Move to RecentlyCompleted for 90-day retention"
print_msg $NC "  • Create archive in Dropbox"

# Confirm
echo
read -p "Proceed with archive? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_msg $RED "Archive cancelled."
    exit 1
fi

# Create Dropbox structure
YEAR=$(echo "$PROJECT_NAME" | cut -d'-' -f1)
MONTH=$(echo "$PROJECT_NAME" | cut -d'-' -f2)
MONTH_NAME=$(date -j -f "%m" "$MONTH" +"%m-%B" 2>/dev/null || echo "$MONTH")
DROPBOX_DIR="$DROPBOX_BASE/$YEAR/$MONTH_NAME/$PROJECT_NAME"

print_msg $BLUE "\nCreating Dropbox structure..."
mkdir -p "$DROPBOX_DIR"/{VIDEO_FINALS,PHOTO_SELECTS}

# Copy exports to Dropbox
if [ $EXPORT_COUNT -gt 0 ]; then
    print_msg $BLUE "Copying final videos to Dropbox..."
    cp -v "$PROJECT_PATH/VIDEO/EXPORTS/"*.mp4 "$DROPBOX_DIR/VIDEO_FINALS/" 2>/dev/null || true
    cp -v "$PROJECT_PATH/VIDEO/EXPORTS/"*.mov "$DROPBOX_DIR/VIDEO_FINALS/" 2>/dev/null || true
fi

# Handle photos
if [ "$PHOTOS_ONLY" = false ] && [ $PHOTO_COUNT -gt 0 ]; then
    print_msg $BLUE "Copying all photos to Dropbox..."
    # Check for edited photos first
    EDITED_COUNT=$(find "$PROJECT_PATH/PHOTOS/EDITED" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ $EDITED_COUNT -gt 0 ]; then
        cp -v "$PROJECT_PATH/PHOTOS/EDITED/"* "$DROPBOX_DIR/PHOTO_SELECTS/" 2>/dev/null || true
    else
        # Copy best photos (you can customize this logic)
        print_msg $YELLOW "No edited photos found. Copying first 20 photos as samples..."
        find "$PROJECT_PATH/PHOTOS/RAW" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0 2>/dev/null | head -z -20 | xargs -0 -I {} cp {} "$DROPBOX_DIR/PHOTO_SELECTS/"
    fi
fi

# Copy metadata
print_msg $BLUE "Copying project metadata..."
cp -r "$PROJECT_PATH/METADATA" "$DROPBOX_DIR/" 2>/dev/null || true
cp "$PROJECT_PATH/README.txt" "$DROPBOX_DIR/" 2>/dev/null || true

# Handle video compression if requested
if [ "$COMPRESS_VIDEO" = true ] && [ $VIDEO_COUNT -gt 0 ]; then
    print_msg $YELLOW "\nCompressing videos with HEVC..."
    print_msg $YELLOW "This will take some time..."

    COMPRESSED_DIR="$PROJECT_PATH/VIDEO/COMPRESSED"
    mkdir -p "$COMPRESSED_DIR"

    for video in "$PROJECT_PATH/VIDEO/RAW/"*.{mp4,MP4,mov,MOV} 2>/dev/null; do
        if [ -f "$video" ]; then
            filename=$(basename "$video")
            name="${filename%.*}"
            ext="${filename##*.}"
            output="$COMPRESSED_DIR/${name}_HEVC.mp4"

            if [ ! -f "$output" ]; then
                print_msg $NC "  Compressing: $filename"
                ffmpeg -i "$video" -c:v libx265 -crf 23 -preset medium -c:a aac -b:a 128k "$output" -y 2>/dev/null || {
                    print_msg $RED "  Failed to compress $filename"
                    continue
                }

                # Show compression ratio
                original_size=$(stat -f%z "$video" 2>/dev/null || echo 0)
                compressed_size=$(stat -f%z "$output" 2>/dev/null || echo 0)
                if [ $original_size -gt 0 ] && [ $compressed_size -gt 0 ]; then
                    ratio=$(echo "scale=1; 100 - ($compressed_size * 100 / $original_size)" | bc)
                    print_msg $GREEN "    Reduced by ${ratio}%"
                fi
            else
                print_msg $NC "  Already compressed: $filename"
            fi
        fi
    done
fi

# Handle RAW upload if requested
if [ "$KEEP_RAW" = true ]; then
    print_msg $YELLOW "\nUploading RAW footage to Dropbox..."
    print_msg $YELLOW "This will take significant time and bandwidth..."

    mkdir -p "$DROPBOX_DIR/RAW_ARCHIVE"

    if [ "$COMPRESS_VIDEO" = true ] && [ -d "$PROJECT_PATH/VIDEO/COMPRESSED" ]; then
        print_msg $NC "Copying compressed videos..."
        cp -r "$PROJECT_PATH/VIDEO/COMPRESSED/"* "$DROPBOX_DIR/RAW_ARCHIVE/" 2>/dev/null || true
    else
        print_msg $NC "Copying original RAW videos..."
        cp -r "$PROJECT_PATH/VIDEO/RAW/"* "$DROPBOX_DIR/RAW_ARCHIVE/" 2>/dev/null || true
    fi

    # Copy SRT files
    cp -r "$PROJECT_PATH/VIDEO/SRT/"* "$DROPBOX_DIR/RAW_ARCHIVE/" 2>/dev/null || true

    print_msg $YELLOW "\n⚠️  IMPORTANT: After Dropbox finishes syncing:"
    print_msg $YELLOW "   1. Right-click the RAW_ARCHIVE folder in Finder"
    print_msg $YELLOW "   2. Select 'Make Available Online-only'"
    print_msg $YELLOW "   This will free up local disk space"
fi

# Move to RecentlyCompleted
print_msg $BLUE "\nMoving project to RecentlyCompleted..."
mkdir -p "$COMPLETED_DIR"
if [ -d "$COMPLETED_DIR/$PROJECT_NAME" ]; then
    print_msg $YELLOW "Project already exists in RecentlyCompleted. Overwriting..."
    rm -rf "$COMPLETED_DIR/$PROJECT_NAME"
fi
mv "$PROJECT_PATH" "$COMPLETED_DIR/"

# Add to cleanup schedule
CLEANUP_DATE=$(date -v+90d +%Y-%m-%d 2>/dev/null || date -d "+90 days" +%Y-%m-%d)
echo "$PROJECT_NAME|$CLEANUP_DATE|$(date)|$KEEP_RAW" >> "$CLEANUP_LOG"

# Create summary report
SUMMARY_FILE="$DROPBOX_DIR/archive_summary.txt"
cat > "$SUMMARY_FILE" <<EOF
========================================
ARCHIVE SUMMARY
========================================
Project: $PROJECT_NAME
Archive Date: $(date)
90-Day Review Date: $CLEANUP_DATE

Original Location: $PROJECT_PATH
Current Location: $COMPLETED_DIR/$PROJECT_NAME
Dropbox Location: $DROPBOX_DIR

FILES ARCHIVED
--------------
Video Exports: $EXPORT_COUNT files
Photos: Selective (best/edited only)
RAW Footage: $([ "$KEEP_RAW" = true ] && echo "Uploaded to Dropbox (online-only)" || echo "Not uploaded (keeping exports only)")
Compression: $([ "$COMPRESS_VIDEO" = true ] && echo "HEVC compressed" || echo "Original format")

STORAGE SUMMARY
--------------
Original Size: $TOTAL_SIZE
RAW Video Size: $RAW_SIZE
Archive Method: $([ "$KEEP_RAW" = true ] && echo "Full archive" || echo "Finals only")

NEXT STEPS
----------
1. Wait for Dropbox to finish syncing
2. Verify files uploaded correctly at dropbox.com
$([ "$KEEP_RAW" = true ] && echo "3. Right-click RAW_ARCHIVE folder → 'Make Available Online-only'" || echo "3. RAW footage will be auto-deleted after 90 days")

EOF

# Final summary
print_msg $GREEN "\n========================================="
print_msg $GREEN "✓ ARCHIVE COMPLETE!"
print_msg $GREEN "========================================="
print_msg $GREEN "Project: $PROJECT_NAME"
print_msg $GREEN ""
print_msg $BLUE "Local Storage:"
print_msg $NC "  • Moved to: $COMPLETED_DIR/$PROJECT_NAME"
print_msg $NC "  • Will remain for: 90 days"
print_msg $NC "  • Review date: $CLEANUP_DATE"
print_msg $GREEN ""
print_msg $BLUE "Dropbox Archive:"
print_msg $NC "  • Location: $DROPBOX_DIR"
print_msg $NC "  • Finals: $([ $EXPORT_COUNT -gt 0 ] && echo "$EXPORT_COUNT videos" || echo "No videos")"
print_msg $NC "  • Photos: $([ $PHOTO_COUNT -gt 0 ] && echo "Best selections" || echo "No photos")"
print_msg $NC "  • RAW: $([ "$KEEP_RAW" = true ] && echo "Uploaded (set to online-only after sync)" || echo "Not uploaded")"
print_msg $GREEN ""

# Show Dropbox sync status
if command -v dropbox &> /dev/null; then
    print_msg $YELLOW "Checking Dropbox sync status..."
    dropbox status || true
else
    print_msg $YELLOW "Monitor Dropbox icon in menu bar for sync progress"
fi

print_msg $GREEN ""
print_msg $YELLOW "Next steps:"
print_msg $NC "1. Wait for Dropbox sync to complete"
print_msg $NC "2. Verify files at dropbox.com"
if [ "$KEEP_RAW" = true ]; then
    print_msg $NC "3. Right-click RAW_ARCHIVE → 'Make Available Online-only'"
fi
print_msg $NC "4. Project will auto-appear for review in 90 days"