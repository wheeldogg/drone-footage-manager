#!/bin/bash

# drone-summary.sh - Get overview of drone projects and storage usage
# Shows active projects, recently completed, and cleanup reminders
# Usage: ./drone-summary.sh [project-name]

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
    local size=$1
    if [ -z "$size" ]; then
        echo "0 B"
        return
    fi
    if [ $size -gt 1073741824 ]; then
        echo "$(echo "scale=2; $size / 1073741824" | bc) GB"
    elif [ $size -gt 1048576 ]; then
        echo "$(echo "scale=2; $size / 1048576" | bc) MB"
    elif [ $size -gt 1024 ]; then
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    else
        echo "$size B"
    fi
}

# Function to get project stats
get_project_stats() {
    local project_path=$1
    local project_name=$(basename "$project_path")

    # Count files
    local video_count=$(find "$project_path/VIDEO/RAW" -type f \( -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | wc -l | tr -d ' ')
    local photo_count=$(find "$project_path/PHOTOS" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) 2>/dev/null | wc -l | tr -d ' ')
    local export_count=$(find "$project_path/VIDEO/EXPORTS" -type f 2>/dev/null | wc -l | tr -d ' ')

    # Get sizes
    local total_size=$(du -sb "$project_path" 2>/dev/null | cut -f1 || echo 0)
    local formatted_size=$(format_size $total_size)

    echo "$project_name|$video_count|$photo_count|$export_count|$formatted_size|$total_size"
}

# Check if external drive is mounted
if [ ! -d "$EXTERNAL_DRIVE" ]; then
    print_msg $RED "Error: External drive '$EXTERNAL_DRIVE' not mounted!"
    exit 1
fi

# If specific project requested
if [ $# -gt 0 ]; then
    PROJECT_NAME="$1"
    print_msg $CYAN "\n========================================="
    print_msg $CYAN "Project Details: $PROJECT_NAME"
    print_msg $CYAN "========================================="

    # Search for project
    PROJECT_PATH=""
    if [ -d "$ACTIVE_DIR/$PROJECT_NAME" ]; then
        PROJECT_PATH="$ACTIVE_DIR/$PROJECT_NAME"
        STATUS="Active"
    elif [ -d "$COMPLETED_DIR/$PROJECT_NAME" ]; then
        PROJECT_PATH="$COMPLETED_DIR/$PROJECT_NAME"
        STATUS="Recently Completed"
    elif [ -d "$ARCHIVE_DIR/$PROJECT_NAME" ]; then
        PROJECT_PATH="$ARCHIVE_DIR/$PROJECT_NAME"
        STATUS="Archived"
    fi

    if [ -z "$PROJECT_PATH" ]; then
        # Try pattern matching
        MATCHES=$(find "$DRONE_BASE" -type d -name "*$PROJECT_NAME*" -maxdepth 2 2>/dev/null)
        if [ ! -z "$MATCHES" ]; then
            print_msg $YELLOW "Did you mean one of these?"
            echo "$MATCHES" | while read match; do
                print_msg $NC "  • $(basename "$match")"
            done
        else
            print_msg $RED "Project not found: $PROJECT_NAME"
        fi
        exit 1
    fi

    # Show detailed stats
    print_msg $GREEN "\nStatus: $STATUS"
    print_msg $GREEN "Location: $PROJECT_PATH"

    # File counts
    print_msg $BLUE "\nFile Inventory:"
    VIDEO_COUNT=$(find "$PROJECT_PATH/VIDEO/RAW" -type f \( -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | wc -l | tr -d ' ')
    PHOTO_COUNT=$(find "$PROJECT_PATH/PHOTOS" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) 2>/dev/null | wc -l | tr -d ' ')
    PANO_COUNT=$(find "$PROJECT_PATH/PHOTOS/PANORAMA" -type d -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
    EXPORT_COUNT=$(find "$PROJECT_PATH/VIDEO/EXPORTS" -type f 2>/dev/null | wc -l | tr -d ' ')
    SRT_COUNT=$(find "$PROJECT_PATH/VIDEO/SRT" -type f -iname "*.srt" 2>/dev/null | wc -l | tr -d ' ')

    print_msg $NC "  Videos: $VIDEO_COUNT files"
    print_msg $NC "  Photos: $PHOTO_COUNT files"
    print_msg $NC "  Panoramas: $PANO_COUNT sets"
    print_msg $NC "  Telemetry: $SRT_COUNT files"
    print_msg $NC "  Exports: $EXPORT_COUNT files"

    # Size breakdown
    print_msg $BLUE "\nStorage Usage:"
    VIDEO_SIZE=$(du -sh "$PROJECT_PATH/VIDEO" 2>/dev/null | cut -f1 || echo "0")
    PHOTO_SIZE=$(du -sh "$PROJECT_PATH/PHOTOS" 2>/dev/null | cut -f1 || echo "0")
    TOTAL_SIZE=$(du -sh "$PROJECT_PATH" 2>/dev/null | cut -f1 || echo "0")

    print_msg $NC "  Video folder: $VIDEO_SIZE"
    print_msg $NC "  Photo folder: $PHOTO_SIZE"
    print_msg $NC "  Total: $TOTAL_SIZE"

    # Show recent files
    print_msg $BLUE "\nRecent Videos:"
    find "$PROJECT_PATH/VIDEO/RAW" -type f \( -iname "*.mp4" -o -iname "*.mov" \) -print0 2>/dev/null | xargs -0 ls -lt 2>/dev/null | head -5 | while read line; do
        print_msg $NC "  $line"
    done

    if [ $EXPORT_COUNT -gt 0 ]; then
        print_msg $BLUE "\nExported Files:"
        ls -lh "$PROJECT_PATH/VIDEO/EXPORTS/"* 2>/dev/null | while read line; do
            print_msg $NC "  $line"
        done
    fi

    # Check Dropbox status
    YEAR=$(echo "$PROJECT_NAME" | cut -d'-' -f1)
    MONTH=$(echo "$PROJECT_NAME" | cut -d'-' -f2)
    MONTH_NAME=$(date -j -f "%m" "$MONTH" +"%m-%B" 2>/dev/null || echo "$MONTH")
    DROPBOX_PATH="$DROPBOX_BASE/$YEAR/$MONTH_NAME/$PROJECT_NAME"

    if [ -d "$DROPBOX_PATH" ]; then
        print_msg $GREEN "\n✓ Backed up to Dropbox"
        print_msg $NC "  Location: $DROPBOX_PATH"
        DROPBOX_SIZE=$(du -sh "$DROPBOX_PATH" 2>/dev/null | cut -f1 || echo "0")
        print_msg $NC "  Size in Dropbox: $DROPBOX_SIZE"
    else
        print_msg $YELLOW "\n⚠ Not yet in Dropbox"
    fi

    # Check cleanup schedule
    if [ -f "$CLEANUP_LOG" ] && grep -q "$PROJECT_NAME" "$CLEANUP_LOG"; then
        CLEANUP_INFO=$(grep "$PROJECT_NAME" "$CLEANUP_LOG" | tail -1)
        CLEANUP_DATE=$(echo "$CLEANUP_INFO" | cut -d'|' -f2)
        print_msg $BLUE "\n90-Day Review Date: $CLEANUP_DATE"
    fi

    exit 0
fi

# OVERALL SUMMARY MODE
print_msg $CYAN "\n========================================="
print_msg $CYAN "      DRONE PROJECTS OVERVIEW"
print_msg $CYAN "========================================="

# Drive status
DRIVE_TOTAL=$(df -h "$EXTERNAL_DRIVE" | tail -1 | awk '{print $2}')
DRIVE_USED=$(df -h "$EXTERNAL_DRIVE" | tail -1 | awk '{print $3}')
DRIVE_AVAIL=$(df -h "$EXTERNAL_DRIVE" | tail -1 | awk '{print $4}')
DRIVE_PERCENT=$(df -h "$EXTERNAL_DRIVE" | tail -1 | awk '{print $5}')

print_msg $BLUE "\nExternal Drive Status:"
print_msg $NC "  Drive: $(basename "$EXTERNAL_DRIVE")"
print_msg $NC "  Total: $DRIVE_TOTAL"
print_msg $NC "  Used: $DRIVE_USED ($DRIVE_PERCENT)"
print_msg $NC "  Available: $DRIVE_AVAIL"

# Active Projects
print_msg $GREEN "\n📹 ACTIVE PROJECTS:"
print_msg $GREEN "-------------------"
if [ -d "$ACTIVE_DIR" ]; then
    ACTIVE_COUNT=0
    ACTIVE_TOTAL=0
    for project in "$ACTIVE_DIR"/*; do
        if [ -d "$project" ]; then
            STATS=$(get_project_stats "$project")
            PROJECT_NAME=$(echo "$STATS" | cut -d'|' -f1)
            VIDEO_COUNT=$(echo "$STATS" | cut -d'|' -f2)
            PHOTO_COUNT=$(echo "$STATS" | cut -d'|' -f3)
            EXPORT_COUNT=$(echo "$STATS" | cut -d'|' -f4)
            SIZE=$(echo "$STATS" | cut -d'|' -f5)
            RAW_SIZE=$(echo "$STATS" | cut -d'|' -f6)

            print_msg $YELLOW "  $PROJECT_NAME"
            print_msg $NC "    Videos: $VIDEO_COUNT | Photos: $PHOTO_COUNT | Exports: $EXPORT_COUNT | Size: $SIZE"

            ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
            ACTIVE_TOTAL=$((ACTIVE_TOTAL + RAW_SIZE))
        fi
    done

    if [ $ACTIVE_COUNT -eq 0 ]; then
        print_msg $NC "  No active projects"
    else
        print_msg $BLUE "\n  Total: $ACTIVE_COUNT projects, $(format_size $ACTIVE_TOTAL)"
    fi
fi

# Recently Completed
print_msg $MAGENTA "\n⏰ RECENTLY COMPLETED (90-day retention):"
print_msg $MAGENTA "------------------------------------------"
if [ -d "$COMPLETED_DIR" ]; then
    COMPLETED_COUNT=0
    COMPLETED_TOTAL=0
    for project in "$COMPLETED_DIR"/*; do
        if [ -d "$project" ]; then
            STATS=$(get_project_stats "$project")
            PROJECT_NAME=$(echo "$STATS" | cut -d'|' -f1)
            SIZE=$(echo "$STATS" | cut -d'|' -f5)
            RAW_SIZE=$(echo "$STATS" | cut -d'|' -f6)

            # Check age
            PROJECT_AGE=$(find "$project" -maxdepth 0 -type d -mtime +0 -exec stat -f "%Sm" -t "%Y-%m-%d" {} \; 2>/dev/null)
            DAYS_OLD=$(find "$project" -maxdepth 0 -type d -mtime +0 -exec stat -f "%Sa" -t "%j" {} \; 2>/dev/null || echo "0")

            print_msg $YELLOW "  $PROJECT_NAME"
            print_msg $NC "    Size: $SIZE | Age: ~$DAYS_OLD days"

            # Check cleanup schedule
            if [ -f "$CLEANUP_LOG" ] && grep -q "$PROJECT_NAME" "$CLEANUP_LOG"; then
                CLEANUP_DATE=$(grep "$PROJECT_NAME" "$CLEANUP_LOG" | tail -1 | cut -d'|' -f2)
                DAYS_LEFT=$(( ($(date -j -f "%Y-%m-%d" "$CLEANUP_DATE" +%s 2>/dev/null || date -d "$CLEANUP_DATE" +%s) - $(date +%s)) / 86400 ))
                if [ $DAYS_LEFT -le 7 ]; then
                    print_msg $RED "    ⚠️  Review in $DAYS_LEFT days!"
                else
                    print_msg $NC "    Review date: $CLEANUP_DATE ($DAYS_LEFT days)"
                fi
            fi

            COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
            COMPLETED_TOTAL=$((COMPLETED_TOTAL + RAW_SIZE))
        fi
    done

    if [ $COMPLETED_COUNT -eq 0 ]; then
        print_msg $NC "  No recently completed projects"
    else
        print_msg $BLUE "\n  Total: $COMPLETED_COUNT projects, $(format_size $COMPLETED_TOTAL)"
    fi
fi

# Upcoming cleanup reminders
if [ -f "$CLEANUP_LOG" ]; then
    print_msg $RED "\n🗓️  UPCOMING REVIEWS (next 7 days):"
    print_msg $RED "------------------------------------"

    TODAY=$(date +%s)
    WEEK_FROM_NOW=$((TODAY + 604800))
    FOUND_UPCOMING=false

    while IFS='|' read -r project cleanup_date archive_date keep_raw; do
        CLEANUP_TIMESTAMP=$(date -j -f "%Y-%m-%d" "$cleanup_date" +%s 2>/dev/null || date -d "$cleanup_date" +%s 2>/dev/null || echo 0)
        if [ $CLEANUP_TIMESTAMP -gt 0 ] && [ $CLEANUP_TIMESTAMP -le $WEEK_FROM_NOW ] && [ $CLEANUP_TIMESTAMP -ge $TODAY ]; then
            DAYS_LEFT=$(( ($CLEANUP_TIMESTAMP - $TODAY) / 86400 ))
            print_msg $YELLOW "  • $project"
            print_msg $NC "    Review in $DAYS_LEFT days (${cleanup_date})"
            FOUND_UPCOMING=true
        fi
    done < "$CLEANUP_LOG"

    if [ "$FOUND_UPCOMING" = false ]; then
        print_msg $NC "  No projects need review this week"
    fi
fi

# Dropbox Status
print_msg $CYAN "\n☁️  DROPBOX BACKUP STATUS:"
print_msg $CYAN "--------------------------"
if [ -d "$DROPBOX_BASE" ]; then
    DROPBOX_COUNT=$(find "$DROPBOX_BASE" -type d -mindepth 3 -maxdepth 3 2>/dev/null | wc -l | tr -d ' ')
    DROPBOX_SIZE=$(du -sh "$DROPBOX_BASE" 2>/dev/null | cut -f1 || echo "0")
    print_msg $NC "  Projects backed up: $DROPBOX_COUNT"
    print_msg $NC "  Total Dropbox usage: $DROPBOX_SIZE"

    # Check Dropbox sync status if available
    if command -v dropbox &> /dev/null; then
        SYNC_STATUS=$(dropbox status 2>/dev/null | head -1)
        print_msg $NC "  Sync status: $SYNC_STATUS"
    fi
else
    print_msg $YELLOW "  Dropbox folder not found"
    print_msg $NC "  Expected at: $DROPBOX_BASE"
fi

# Quick tips
print_msg $BLUE "\n💡 QUICK COMMANDS:"
print_msg $BLUE "-------------------"
print_msg $NC "  Import footage:    ./drone-import.sh \"ProjectName\""
print_msg $NC "  Archive project:   ./drone-archive.sh \"ProjectName\""
print_msg $NC "  Project details:   ./drone-summary.sh \"ProjectName\""
print_msg $NC "  Compress & keep:   ./drone-archive.sh \"ProjectName\" --compress --keep-raw"

# Storage recommendations
DRIVE_PERCENT_NUM=$(echo "$DRIVE_PERCENT" | tr -d '%')
if [ "$DRIVE_PERCENT_NUM" -gt 80 ]; then
    print_msg $RED "\n⚠️  WARNING: Drive is ${DRIVE_PERCENT} full!"
    print_msg $YELLOW "Consider archiving old projects or getting additional storage."
elif [ "$DRIVE_PERCENT_NUM" -gt 60 ]; then
    print_msg $YELLOW "\n📊 Drive is ${DRIVE_PERCENT} full - plan ahead for archiving"
fi

print_msg $GREEN "\n========================================="