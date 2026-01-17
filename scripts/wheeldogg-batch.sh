#!/bin/bash

# wheeldogg-batch.sh - Multi-platform batch resizer for wheeldogg channel
# Creates all Instagram + YouTube sizes in one command
# Usage: ./scripts/wheeldogg-batch.sh "/path/to/photos/folder"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Quality settings
QUALITY=95

# Function to print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Function to format file size
format_size() {
    local size=${1:-0}
    if [ -z "$size" ] || [ "$size" -eq 0 ] 2>/dev/null; then
        echo "0 B"
    elif [ "$size" -ge 1048576 ]; then
        echo "$(echo "scale=1; $size/1048576" | bc) MB"
    elif [ "$size" -ge 1024 ]; then
        echo "$(echo "scale=0; $size/1024" | bc) KB"
    else
        echo "${size} B"
    fi
}

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    print_msg $RED "Error: ImageMagick is not installed."
    echo "Install with: brew install imagemagick"
    exit 1
fi

# Check arguments
if [ $# -lt 1 ]; then
    print_msg $CYAN "═══════════════════════════════════════════════════════════════"
    print_msg $CYAN "        wheeldogg Batch Resizer - Instagram + YouTube          "
    print_msg $CYAN "═══════════════════════════════════════════════════════════════"
    echo ""
    print_msg $YELLOW "Usage: $0 \"/path/to/photos/folder\""
    echo ""
    print_msg $BLUE "This creates ALL platform sizes in one command:"
    echo ""
    print_msg $MAGENTA "Instagram:"
    echo "  • Feed Square    (1080x1080)  - 1:1 posts"
    echo "  • Feed Portrait  (1080x1350)  - 4:5 posts"
    echo "  • Feed Landscape (1080 wide)  - Full width, no crop"
    echo "  • Stories/Reels  (1080x1920)  - 9:16 vertical"
    echo ""
    print_msg $RED "YouTube:"
    echo "  • Thumbnail      (1280x720)   - Video thumbnails"
    echo "  • Thumbnail HD   (1920x1080)  - High-res thumbnails"
    echo "  • Community      (1200x1200)  - Community posts"
    echo ""
    print_msg $GREEN "Example:"
    echo "  $0 \"PHOTOS/CASTLEISLAND Nells Birthday\""
    exit 0
fi

SOURCE_DIR="$1"

# Convert to absolute path if relative
if [[ "$SOURCE_DIR" != /* ]]; then
    SOURCE_DIR="$(pwd)/$SOURCE_DIR"
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    print_msg $RED "Error: Directory not found: $SOURCE_DIR"
    exit 1
fi

# Get parent directory for output
PARENT_DIR=$(dirname "$SOURCE_DIR")
OUTPUT_BASE="$PARENT_DIR/WHEELDOGG_READY"

# Count photos
PHOTO_COUNT=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | wc -l | tr -d ' ')

if [ "$PHOTO_COUNT" -eq 0 ]; then
    print_msg $RED "Error: No photos found in $SOURCE_DIR"
    exit 1
fi

# Header
print_msg $CYAN "═══════════════════════════════════════════════════════════════"
print_msg $CYAN "        wheeldogg Batch Resizer - Instagram + YouTube          "
print_msg $CYAN "═══════════════════════════════════════════════════════════════"
echo ""
print_msg $GREEN "Found $PHOTO_COUNT photos to process"
print_msg $NC "Source: $SOURCE_DIR"
print_msg $NC "Output: $OUTPUT_BASE"
echo ""

# Create output directories
print_msg $BLUE "Creating output directories..."
mkdir -p "$OUTPUT_BASE/instagram/feed_square"
mkdir -p "$OUTPUT_BASE/instagram/feed_portrait"
mkdir -p "$OUTPUT_BASE/instagram/feed_landscape"
mkdir -p "$OUTPUT_BASE/instagram/stories_reels"
mkdir -p "$OUTPUT_BASE/youtube/thumbnails"
mkdir -p "$OUTPUT_BASE/youtube/thumbnails_hd"
mkdir -p "$OUTPUT_BASE/youtube/community"

echo ""
print_msg $BLUE "Processing photos..."
echo "────────────────────────────────────────────────────────────────"

PROCESSED=0
TOTAL_ORIGINAL_SIZE=0
TOTAL_OUTPUT_SIZE=0

# Process each image
shopt -s nullglob
for IMG in "$SOURCE_DIR"/*.{jpg,JPG,jpeg,JPEG,png,PNG}; do
    [ -f "$IMG" ] || continue

    BASENAME=$(basename "$IMG")
    NAME="${BASENAME%.*}"

    # Get original file size
    ORIGINAL_SIZE=$(stat -f%z "$IMG" 2>/dev/null || stat -c%s "$IMG" 2>/dev/null)
    TOTAL_ORIGINAL_SIZE=$((TOTAL_ORIGINAL_SIZE + ORIGINAL_SIZE))

    PROCESSED=$((PROCESSED + 1))
    echo ""
    print_msg $YELLOW "[$PROCESSED/$PHOTO_COUNT] $BASENAME"
    print_msg $NC "  Original: $(format_size $ORIGINAL_SIZE)"

    # ═══════════════════════════════════════════════════════════════
    # INSTAGRAM FORMATS
    # ═══════════════════════════════════════════════════════════════

    # Feed Square (1080x1080) - 1:1
    OUTPUT_FILE="$OUTPUT_BASE/instagram/feed_square/${NAME}_square.jpg"
    convert "$IMG" -resize "1080x1080^" -gravity center -extent "1080x1080" \
        -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + SIZE))
        print_msg $MAGENTA "  ✓ IG Square:     $(format_size $SIZE)"
    fi

    # Feed Portrait (1080x1350) - 4:5
    OUTPUT_FILE="$OUTPUT_BASE/instagram/feed_portrait/${NAME}_portrait.jpg"
    convert "$IMG" -resize "1080x1350^" -gravity center -extent "1080x1350" \
        -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + SIZE))
        print_msg $MAGENTA "  ✓ IG Portrait:   $(format_size $SIZE)"
    fi

    # Feed Landscape (1080 width, original aspect) - full width, no crop
    OUTPUT_FILE="$OUTPUT_BASE/instagram/feed_landscape/${NAME}_landscape.jpg"
    convert "$IMG" -resize "1080x>" \
        -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + SIZE))
        print_msg $MAGENTA "  ✓ IG Landscape:  $(format_size $SIZE)"
    fi

    # Stories/Reels (1080x1920) - 9:16
    OUTPUT_FILE="$OUTPUT_BASE/instagram/stories_reels/${NAME}_story.jpg"
    convert "$IMG" -resize "1080x1920^" -gravity center -extent "1080x1920" \
        -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + SIZE))
        print_msg $MAGENTA "  ✓ IG Story:      $(format_size $SIZE)"
    fi

    # ═══════════════════════════════════════════════════════════════
    # YOUTUBE FORMATS
    # ═══════════════════════════════════════════════════════════════

    # Thumbnail (1280x720) - 16:9
    OUTPUT_FILE="$OUTPUT_BASE/youtube/thumbnails/${NAME}_thumb.jpg"
    convert "$IMG" -resize "1280x720^" -gravity center -extent "1280x720" \
        -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + SIZE))
        print_msg $RED "  ✓ YT Thumbnail:  $(format_size $SIZE)"
    fi

    # Thumbnail HD (1920x1080) - 16:9
    OUTPUT_FILE="$OUTPUT_BASE/youtube/thumbnails_hd/${NAME}_thumb_hd.jpg"
    convert "$IMG" -resize "1920x1080^" -gravity center -extent "1920x1080" \
        -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + SIZE))
        print_msg $RED "  ✓ YT Thumb HD:   $(format_size $SIZE)"
    fi

    # Community Post (1200x1200) - 1:1
    OUTPUT_FILE="$OUTPUT_BASE/youtube/community/${NAME}_community.jpg"
    convert "$IMG" -resize "1200x1200^" -gravity center -extent "1200x1200" \
        -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + SIZE))
        print_msg $RED "  ✓ YT Community:  $(format_size $SIZE)"
    fi

done

# Summary
echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
print_msg $GREEN "═══════════════════════════════════════════════════════════════"
print_msg $GREEN "                    Processing Complete!                       "
print_msg $GREEN "═══════════════════════════════════════════════════════════════"
echo ""
print_msg $NC "Photos processed: $PROCESSED"
print_msg $NC "Original total:   $(format_size $TOTAL_ORIGINAL_SIZE)"
print_msg $NC "Output total:     $(format_size $TOTAL_OUTPUT_SIZE)"

if [ $TOTAL_ORIGINAL_SIZE -gt 0 ]; then
    # Calculate files created (7 per photo)
    FILES_CREATED=$((PROCESSED * 7))
    print_msg $NC "Files created:    $FILES_CREATED"
fi

echo ""
print_msg $BLUE "Output location:"
print_msg $YELLOW "  $OUTPUT_BASE"
echo ""
print_msg $MAGENTA "Instagram ready:"
echo "  • feed_square/    - 1080x1080 (1:1)"
echo "  • feed_portrait/  - 1080x1350 (4:5)"
echo "  • feed_landscape/ - 1080 wide (full width, no crop)"
echo "  • stories_reels/  - 1080x1920 (9:16)"
echo ""
print_msg $RED "YouTube ready:"
echo "  • thumbnails/     - 1280x720 (16:9)"
echo "  • thumbnails_hd/  - 1920x1080 (16:9)"
echo "  • community/      - 1200x1200 (1:1)"
echo ""
print_msg $GREEN "Your content is ready for wheeldogg! 🐕"
echo ""
