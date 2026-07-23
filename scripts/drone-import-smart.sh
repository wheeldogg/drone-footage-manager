#!/bin/bash

# drone-import-smart.sh - Smart import that auto-detects dates from files
# Automatically organizes by actual file dates, not project name
# Usage: ./drone-import-smart.sh [--all-dates] [--date YYYYMMDD] [custom_name]
#
#   --all-dates      Import every detected date into its own folder, no prompting.
#   --date YYYYMMDD  Import only this one date (implies --all-dates behaviour).

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration (destination, SD paths) - see scripts/drone-config.sh
source "$(cd "$(dirname "$0")" && pwd)/drone-config.sh"

# Function to print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Parse arguments
ALL_DATES=false
ONLY_DATE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --all-dates) ALL_DATES=true ;;
        --date)      ONLY_DATE="$2"; ALL_DATES=true; shift ;;
    esac
    shift
done

# Check if SD card is mounted
if [ ! -d "$SD_ROOT" ]; then
    print_msg $RED "Error: DJI SD card not found at $SD_ROOT!"
    exit 1
fi

if [ ! -d "$SD_PATH" ]; then
    print_msg $RED "Error: No DJI folder found at $SD_PATH!"
    exit 1
fi

# Track failures across the whole run
FAILED_ITEMS=()

# Resolve YYYYMMDD -> month folder name (e.g. 07 -> 07-July)
month_folder() {
    local month=$1
    date -j -f "%m" "$month" +"%m-%B" 2>/dev/null || echo "${month}-Month"
}

# Copy every file matching a glob for one date into a destination subfolder.
# Uses rsync so re-runs skip already-copied files (resumable + idempotent).
# Args: <date> <extension> <destination dir>
copy_by_ext() {
    local date=$1
    local ext=$2
    local dest=$3

    local list
    list=$(mktemp)
    ( cd "$SD_PATH" && ls -1 | grep -E "^DJI_${date}[0-9]{6}_[0-9]+_D\.${ext}$" ) > "$list" 2>/dev/null

    local count
    count=$(wc -l < "$list" | tr -d ' ')
    if [ "$count" -eq 0 ]; then
        rm -f "$list"
        return 0
    fi

    mkdir -p "$dest"
    if rsync -a --files-from="$list" "$SD_PATH/" "$dest/"; then
        print_msg $NC "    ${ext}: $count file(s)"
    else
        print_msg $RED "    ✗ ${ext} copy reported errors for $date"
        FAILED_ITEMS+=("$date/$ext")
    fi
    rm -f "$list"
}

# Given a DJI sequence index (e.g. 0567), return the YYYYMMDD of the matching clip
date_for_index() {
    local index=$1
    ( cd "$SD_PATH" && ls -1 ) 2>/dev/null \
        | grep -m1 -E "^DJI_[0-9]{14}_${index}_D\." \
        | sed -n 's/^DJI_\([0-9]\{8\}\).*/\1/p'
}

# Write a per-project metadata summary
write_metadata() {
    local project_dir=$1
    local project_name=$2
    local date=$3

    mkdir -p "$project_dir/METADATA"
    {
        echo "Project: $project_name"
        echo "Flight date: $date"
        echo "Import date: $(date)"
        echo "Source: $SD_PATH"
        echo ""
        echo "FILE COUNT"
        echo "----------"
        echo "Videos:    $(find "$project_dir/VIDEO/RAW" -type f 2>/dev/null | wc -l | tr -d ' ')"
        echo "Telemetry: $(find "$project_dir/VIDEO/SRT" -type f 2>/dev/null | wc -l | tr -d ' ')"
        echo "Proxies:   $(find "$project_dir/VIDEO/LRF" -type f 2>/dev/null | wc -l | tr -d ' ')"
        echo "Photos:    $(find "$project_dir/PHOTOS/RAW" -type f 2>/dev/null | wc -l | tr -d ' ')"
        echo ""
        echo "VIDEO FILES"
        echo "-----------"
        ls -lh "$project_dir/VIDEO/RAW/" 2>/dev/null
        echo ""
        echo "PHOTO FILES"
        echo "-----------"
        ls -1 "$project_dir/PHOTOS/RAW/" 2>/dev/null
    } > "$project_dir/METADATA/file_list.txt"
}

# Import a single date into its own project folder
import_date() {
    local date=$1
    local year=${date:0:4}
    local month=${date:4:2}
    local day=${date:6:2}
    local month_name
    month_name=$(month_folder "$month")

    local project_name="${year}-${month}-${day}_Drone_Footage"
    local project_dir="$DEST_BASE/$year/$month_name/$project_name"

    print_msg $CYAN "\n--- $project_name ---"
    mkdir -p "$project_dir"/{VIDEO/RAW,VIDEO/SRT,VIDEO/LRF,PHOTOS/RAW,PHOTOS/INSTAGRAM,PHOTOS/PANORAMA,METADATA,MUSIC}

    copy_by_ext "$date" "MP4" "$project_dir/VIDEO/RAW"
    copy_by_ext "$date" "SRT" "$project_dir/VIDEO/SRT"
    copy_by_ext "$date" "LRF" "$project_dir/VIDEO/LRF"
    copy_by_ext "$date" "JPG" "$project_dir/PHOTOS/RAW"

    write_metadata "$project_dir" "$project_name" "$date"
    print_msg $GREEN "  ✓ $project_dir"
}

# Copy indexed sets (HYPERLAPSE / PANORAMA) into the project of the date they belong to.
# Set folders are named like 001_0567, where 0567 is the DJI sequence index.
# Args: <source root> <subpath within project, e.g. VIDEO/HYPERLAPSE> <label>
import_indexed_sets() {
    local src_root=$1
    local subpath=$2
    local label=$3

    [ -d "$src_root" ] || return 0

    local found=false
    for set_dir in "$src_root"/*; do
        [ -d "$set_dir" ] || continue

        local set_name
        set_name=$(basename "$set_dir")

        # Skip empty sets
        if [ -z "$(ls -A "$set_dir" 2>/dev/null)" ]; then
            print_msg $YELLOW "  Skipping empty $label set: $set_name"
            continue
        fi

        # Attribute by trailing sequence index, falling back to folder mtime
        local index=${set_name##*_}
        local set_date
        set_date=$(date_for_index "$index")
        if [ -z "$set_date" ]; then
            set_date=$(date -r "$set_dir" +%Y%m%d 2>/dev/null)
            print_msg $YELLOW "  $label set $set_name: no matching clip, using folder date $set_date"
        fi
        [ -n "$set_date" ] || { FAILED_ITEMS+=("$label/$set_name"); continue; }

        # Respect a --date restriction
        if [ -n "$ONLY_DATE" ] && [ "$set_date" != "$ONLY_DATE" ]; then
            continue
        fi

        local year=${set_date:0:4}
        local month=${set_date:4:2}
        local day=${set_date:6:2}
        local month_name
        month_name=$(month_folder "$month")
        local project_dir="$DEST_BASE/$year/$month_name/${year}-${month}-${day}_Drone_Footage"
        local dest="$project_dir/$subpath/$set_name"

        mkdir -p "$dest"
        if rsync -a "$set_dir"/ "$dest"/; then
            print_msg $GREEN "  ✓ $label $set_name → ${year}-${month}-${day}"
            found=true
        else
            print_msg $RED "  ✗ $label $set_name copy failed"
            FAILED_ITEMS+=("$label/$set_name")
        fi
    done

    [ "$found" = true ] || true
}

# Analyze dates on SD card
print_msg $CYAN "========================================="
print_msg $CYAN "Analyzing SD Card Contents"
print_msg $CYAN "========================================="
print_msg $NC "Source:      $SD_PATH"
print_msg $NC "Destination: $DEST_BASE"

# Get unique dates from files
print_msg $BLUE "\nDetecting dates from files..."
DATES=$( ( cd "$SD_PATH" && ls -1 ) 2>/dev/null \
    | sed -n 's/^DJI_\([0-9]\{8\}\).*/\1/p' | sort -u )

if [ -z "$DATES" ]; then
    print_msg $RED "No DJI files found on SD card!"
    exit 1
fi

# Restrict to a single date if asked
if [ -n "$ONLY_DATE" ]; then
    if ! echo "$DATES" | grep -qx "$ONLY_DATE"; then
        print_msg $RED "No files found for date $ONLY_DATE on the SD card!"
        exit 1
    fi
    DATES="$ONLY_DATE"
    print_msg $YELLOW "Restricted to a single date: $ONLY_DATE"
fi

# Count dates
DATE_COUNT=$(echo "$DATES" | wc -l | tr -d ' ')

print_msg $GREEN "\nFound footage from $DATE_COUNT date(s):"
for d in $DATES; do
    file_count=$( ( cd "$SD_PATH" && ls -1 ) 2>/dev/null | grep -c "^DJI_${d}" )
    print_msg $NC "  ${d:0:4}-${d:4:2}-${d:6:2}: $file_count files"
done

# Decide on import strategy
if [ $DATE_COUNT -eq 1 ]; then
    SINGLE_DATE=$DATES
    DEFAULT_NAME="${SINGLE_DATE:0:4}-${SINGLE_DATE:4:2}-${SINGLE_DATE:6:2}_Drone_Footage"
    print_msg $GREEN "\nSingle date detected: $DEFAULT_NAME"
else
    FIRST_DATE=$(echo "$DATES" | head -1)
    LAST_DATE=$(echo "$DATES" | tail -1)
    DEFAULT_NAME="${FIRST_DATE:0:4}-${FIRST_DATE:4:2}-${FIRST_DATE:6:2}_to_${LAST_DATE:0:4}-${LAST_DATE:4:2}-${LAST_DATE:6:2}_Drone_Footage"
    print_msg $YELLOW "\nMultiple dates detected!"
    print_msg $NC "Range: ${FIRST_DATE:0:4}-${FIRST_DATE:4:2}-${FIRST_DATE:6:2} to ${LAST_DATE:0:4}-${LAST_DATE:4:2}-${LAST_DATE:6:2}"
fi

# Ask user for confirmation or custom name (skipped with --all-dates)
if [ "$ALL_DATES" = true ]; then
    REPLY=2
    print_msg $BLUE "\n--all-dates: importing each date separately"
else
    echo ""
    print_msg $YELLOW "Import options:"
    print_msg $NC "1) Use auto-detected name: $DEFAULT_NAME"
    print_msg $NC "2) Import each date separately"
    print_msg $NC "3) Enter custom name"
    echo ""
    read -p "Choose option [1-3]: " -n 1 -r
    echo ""
fi

case $REPLY in
    2)
        # Import each date separately
        print_msg $BLUE "\nImporting each date separately..."
        for d in $DATES; do
            import_date "$d"
        done

        # Sets that live outside DJI_001, attributed back to their flight date
        print_msg $BLUE "\nChecking for hyperlapse sets..."
        import_indexed_sets "$HYPERLAPSE_PATH" "VIDEO/HYPERLAPSE" "hyperlapse"

        print_msg $BLUE "\nChecking for panorama sets..."
        import_indexed_sets "$PANORAMA_PATH" "PHOTOS/PANORAMA" "panorama"

        print_msg $GREEN "\n✓ All dates imported separately!"
        ;;

    3)
        # Custom name
        echo ""
        read -p "Enter custom project name: " CUSTOM_NAME
        PROJECT_NAME="${CUSTOM_NAME:-$DEFAULT_NAME}"
        print_msg $BLUE "\nImporting all files to: $PROJECT_NAME"
        exec "$DRONE_SCRIPT_DIR/drone-import-dropbox.sh" "$PROJECT_NAME"
        ;;

    *)
        # Use auto-detected name
        PROJECT_NAME="$DEFAULT_NAME"
        print_msg $BLUE "\nImporting all files to: $PROJECT_NAME"
        exec "$DRONE_SCRIPT_DIR/drone-import-dropbox.sh" "$PROJECT_NAME"
        ;;
esac

print_msg $GREEN "\n========================================="
if [ ${#FAILED_ITEMS[@]} -gt 0 ]; then
    print_msg $RED "⚠️  IMPORT COMPLETED WITH ${#FAILED_ITEMS[@]} FAILURE(S)"
    print_msg $GREEN "========================================="
    for item in "${FAILED_ITEMS[@]}"; do
        print_msg $RED "  $item"
    done
    print_msg $YELLOW "\nRe-run this script to retry (already-copied files are skipped)."
    exit 1
fi

print_msg $GREEN "✓ IMPORT COMPLETE!"
print_msg $GREEN "========================================="
print_msg $NC "Imported to: $DEST_BASE"
print_msg $YELLOW "\nNext steps:"
print_msg $NC "1. Verify the copy:  ./scripts/drone-verify.sh"
print_msg $NC "2. Free up the card: ./scripts/drone-cleanup-sd.sh"
