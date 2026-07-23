#!/bin/bash

# drone-verify.sh - Verify imported footage matches the SD card, byte for byte
# Runs a checksum dry-run comparison per date. Run this BEFORE deleting anything.
# Usage: ./drone-verify.sh [YYYYMMDD]

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

source "$(cd "$(dirname "$0")" && pwd)/drone-config.sh"

print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

if [ ! -d "$SD_PATH" ]; then
    print_msg $RED "Error: SD card not found at $SD_PATH!"
    exit 1
fi

if [ ! -d "$DEST_BASE" ]; then
    print_msg $RED "Error: Destination not found at $DEST_BASE!"
    print_msg $YELLOW "Run ./scripts/drone-import-smart.sh --all-dates first."
    exit 1
fi

month_folder() {
    date -j -f "%m" "$1" +"%m-%B" 2>/dev/null || echo "${1}-Month"
}

# Checksum-compare one extension for one date.
# Prints nothing on success; returns the number of mismatching files.
verify_ext() {
    local date=$1
    local ext=$2
    local dest=$3

    local list
    list=$(mktemp)
    ( cd "$SD_PATH" && ls -1 ) 2>/dev/null \
        | grep -E "^DJI_${date}[0-9]{6}_[0-9]+_D\.${ext}$" > "$list"

    local expected
    expected=$(wc -l < "$list" | tr -d ' ')
    if [ "$expected" -eq 0 ]; then
        rm -f "$list"
        return 0
    fi

    if [ ! -d "$dest" ]; then
        print_msg $RED "    ✗ ${ext}: destination missing ($expected file(s) on card)"
        rm -f "$list"
        return "$expected"
    fi

    # -c checksum, -n dry run: any itemized line means a file is missing or differs
    local diffs
    diffs=$(rsync -rcn --itemize-changes --files-from="$list" "$SD_PATH/" "$dest/" 2>/dev/null | grep -c .)
    rm -f "$list"

    if [ "$diffs" -gt 0 ]; then
        print_msg $RED "    ✗ ${ext}: $diffs of $expected file(s) missing or corrupt"
        return "$diffs"
    fi

    print_msg $NC "    ${ext}: $expected file(s) OK"
    return 0
}

# Which dates to check
if [ $# -ge 1 ]; then
    DATES="$1"
else
    DATES=$( ( cd "$SD_PATH" && ls -1 ) 2>/dev/null \
        | sed -n 's/^DJI_\([0-9]\{8\}\).*/\1/p' | sort -u )
fi

if [ -z "$DATES" ]; then
    print_msg $YELLOW "No DJI files found on the SD card - nothing to verify."
    exit 0
fi

print_msg $CYAN "========================================="
print_msg $CYAN "Verifying import (checksum comparison)"
print_msg $CYAN "========================================="
print_msg $NC "Card:        $SD_PATH"
print_msg $NC "Destination: $DEST_BASE"
print_msg $YELLOW "\nThis reads every file on both sides - it takes a while.\n"

TOTAL_BAD=0
BAD_DATES=()

for d in $DATES; do
    year=${d:0:4}
    month=${d:4:2}
    day=${d:6:2}
    month_name=$(month_folder "$month")
    project_dir="$DEST_BASE/$year/$month_name/${year}-${month}-${day}_Drone_Footage"

    print_msg $BLUE "${year}-${month}-${day}"

    if [ ! -d "$project_dir" ]; then
        print_msg $RED "    ✗ project folder missing: $project_dir"
        BAD_DATES+=("${year}-${month}-${day}")
        TOTAL_BAD=$((TOTAL_BAD + 1))
        continue
    fi

    date_bad=0
    verify_ext "$d" "MP4" "$project_dir/VIDEO/RAW"; date_bad=$((date_bad + $?))
    verify_ext "$d" "SRT" "$project_dir/VIDEO/SRT"; date_bad=$((date_bad + $?))
    verify_ext "$d" "LRF" "$project_dir/VIDEO/LRF"; date_bad=$((date_bad + $?))
    verify_ext "$d" "JPG" "$project_dir/PHOTOS/RAW"; date_bad=$((date_bad + $?))

    if [ $date_bad -gt 0 ]; then
        BAD_DATES+=("${year}-${month}-${day}")
        TOTAL_BAD=$((TOTAL_BAD + date_bad))
    else
        print_msg $GREEN "    ✓ OK"
    fi
done

echo ""
print_msg $CYAN "========================================="
if [ $TOTAL_BAD -eq 0 ]; then
    print_msg $GREEN "✓ ALL DATES VERIFIED"
    print_msg $CYAN "========================================="
    print_msg $NC "Every file on the card has an identical copy in:"
    print_msg $NC "  $DEST_BASE"
    print_msg $YELLOW "\nSafe to free up the card: ./scripts/drone-cleanup-sd.sh"
    exit 0
fi

print_msg $RED "✗ VERIFICATION FAILED - $TOTAL_BAD problem file(s)"
print_msg $CYAN "========================================="
for bad in "${BAD_DATES[@]}"; do
    print_msg $RED "  $bad"
done
print_msg $YELLOW "\nRe-run the import to fix, then verify again:"
print_msg $NC "  ./scripts/drone-import-smart.sh --all-dates"
print_msg $RED "\nDO NOT delete anything from the SD card until this passes."
exit 1
