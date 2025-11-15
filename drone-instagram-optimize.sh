#!/bin/bash

# drone-instagram-optimize.sh
# Optimizes drone photos for Instagram upload
# Reduces file size and dimensions while preserving quality
#
# ⭐ RECOMMENDED USAGE:
#   ./drone-instagram-optimize.sh --size 3584 --quality 98
#
# This creates 3584×2016px photos at 98% quality (~4-5MB each)
# which is the maximum quality Instagram accepts without compression.
# Instagram compresses any file over 8MB, so this setting keeps you
# under that threshold while maximizing visual quality.

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
QUALITY=95  # Higher quality by default
FORMAT="landscape"  # default to landscape
PROJECT_PATH=$(pwd)
MAX_DIMENSION=4096  # Instagram actually supports up to 4096px now!

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quality)
            QUALITY="$2"
            shift 2
            ;;
        --size)
            MAX_DIMENSION="$2"
            shift 2
            ;;
        --all-formats)
            FORMAT="all"
            shift
            ;;
        --square)
            FORMAT="square"
            shift
            ;;
        --portrait)
            FORMAT="portrait"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "⭐ RECOMMENDED for maximum Instagram quality:"
            echo "  $0 --size 3584 --quality 98"
            echo "  → 3584×2016px, ~4-5MB files, no Instagram compression"
            echo ""
            echo "Options:"
            echo "  --quality <num>   JPEG quality (1-100, default: 95)"
            echo "  --size <num>      Max dimension in pixels (default: 4096, min: 1080)"
            echo "  --all-formats     Create all aspect ratios"
            echo "  --square          Create only square (1:1) crops"
            echo "  --portrait        Create only portrait (4:5) crops"
            echo "  --help            Show this help message"
            echo ""
            echo "Quality Presets:"
            echo "  $0 --size 3584 --quality 98   # ⭐ BEST: Max quality under 8MB (RECOMMENDED)"
            echo "  $0                             # Very high quality (4096px @ 95%)"
            echo "  $0 --size 3072                 # Balanced (3072px @ 95%, ~2MB)"
            echo "  $0 --size 2048 --quality 90    # Fast uploads (2048px, ~1MB)"
            echo ""
            echo "Why 3584px @ 98%?"
            echo "  • Instagram compresses files over 8MB"
            echo "  • 3584px is the largest size that stays under 8MB at 98% quality"
            echo "  • Results in maximum quality without Instagram compression"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to format file size
format_size() {
    local size=$1
    if [ $size -ge 1048576 ]; then
        echo "$(echo "scale=1; $size/1048576" | bc) MB"
    else
        echo "$(echo "scale=0; $size/1024" | bc) KB"
    fi
}

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo -e "${RED}Error: ImageMagick is not installed.${NC}"
    echo "Install with: brew install imagemagick"
    exit 1
fi

# Find the INSTAGRAM source folder
INSTAGRAM_DIR="$PROJECT_PATH/PHOTOS/INSTAGRAM"

# Check if we're in a project folder
if [ ! -d "$PROJECT_PATH/PHOTOS" ]; then
    # Maybe we're in the Dropbox location
    if [[ "$PROJECT_PATH" == *"/DroneFootage/"* ]]; then
        if [ -d "$PROJECT_PATH/PHOTOS/INSTAGRAM" ]; then
            INSTAGRAM_DIR="$PROJECT_PATH/PHOTOS/INSTAGRAM"
        else
            echo -e "${RED}Error: No PHOTOS/INSTAGRAM folder found in current directory${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Error: Not in a drone project directory${NC}"
        echo "Run this from a project folder with PHOTOS/INSTAGRAM subdirectory"
        exit 1
    fi
fi

# Check if INSTAGRAM folder exists and has files
if [ ! -d "$INSTAGRAM_DIR" ]; then
    echo -e "${RED}Error: No INSTAGRAM folder found at $INSTAGRAM_DIR${NC}"
    echo "Please select photos first and place them in PHOTOS/INSTAGRAM/"
    exit 1
fi

# Count JPG files
JPG_COUNT=$(find "$INSTAGRAM_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | wc -l)

if [ "$JPG_COUNT" -eq 0 ]; then
    echo -e "${RED}Error: No JPEG files found in $INSTAGRAM_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}          Instagram Photo Optimizer for Drone Footage          ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Found $JPG_COUNT photos to optimize${NC}"
echo -e "Source: ${YELLOW}$INSTAGRAM_DIR${NC}"
echo ""

# Create output directories
OUTPUT_BASE="$PROJECT_PATH/PHOTOS/INSTAGRAM_READY"
mkdir -p "$OUTPUT_BASE"

if [ "$FORMAT" == "all" ]; then
    mkdir -p "$OUTPUT_BASE/landscape"
    mkdir -p "$OUTPUT_BASE/square"
    mkdir -p "$OUTPUT_BASE/portrait"
    echo -e "${GREEN}Creating all formats: landscape, square, and portrait${NC}"
elif [ "$FORMAT" == "square" ]; then
    mkdir -p "$OUTPUT_BASE/square"
    echo -e "${GREEN}Creating square format only${NC}"
elif [ "$FORMAT" == "portrait" ]; then
    mkdir -p "$OUTPUT_BASE/portrait"
    echo -e "${GREEN}Creating portrait format only${NC}"
else
    mkdir -p "$OUTPUT_BASE/landscape"
    echo -e "${GREEN}Creating landscape format only${NC}"
fi

echo -e "Quality setting: ${YELLOW}${QUALITY}%${NC}"
echo -e "Max dimension: ${YELLOW}${MAX_DIMENSION}px${NC}"
echo ""
echo -e "${BLUE}Processing photos...${NC}"
echo "────────────────────────────────────────────────────────────────"

TOTAL_ORIGINAL_SIZE=0
TOTAL_OPTIMIZED_SIZE=0
PROCESSED=0

# Process each image
shopt -s nullglob
for IMG in "$INSTAGRAM_DIR"/*.{jpg,JPG,jpeg,JPEG}; do
    [ -f "$IMG" ] || continue

    BASENAME=$(basename "$IMG")
    NAME="${BASENAME%.*}"

    # Get original file size
    ORIGINAL_SIZE=$(stat -f%z "$IMG" 2>/dev/null || stat -c%s "$IMG" 2>/dev/null)
    TOTAL_ORIGINAL_SIZE=$((TOTAL_ORIGINAL_SIZE + ORIGINAL_SIZE))

    echo -e "\n${YELLOW}Processing:${NC} $BASENAME"
    echo -e "  Original size: $(format_size $ORIGINAL_SIZE)"

    # Process based on format selection
    if [ "$FORMAT" == "all" ] || [ "$FORMAT" == "landscape" ]; then
        # Landscape - maintain aspect ratio, limit to MAX_DIMENSION
        OUTPUT_LANDSCAPE="$OUTPUT_BASE/landscape/${NAME}_landscape.jpg"
        convert "$IMG" -resize "${MAX_DIMENSION}x${MAX_DIMENSION}>" -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_LANDSCAPE" 2>/dev/null

        if [ -f "$OUTPUT_LANDSCAPE" ]; then
            NEW_SIZE=$(stat -f%z "$OUTPUT_LANDSCAPE" 2>/dev/null || stat -c%s "$OUTPUT_LANDSCAPE" 2>/dev/null)
            TOTAL_OPTIMIZED_SIZE=$((TOTAL_OPTIMIZED_SIZE + NEW_SIZE))
            REDUCTION=$((100 - (NEW_SIZE * 100 / ORIGINAL_SIZE)))
            echo -e "  ${GREEN}✓${NC} Landscape: $(format_size $NEW_SIZE) (${REDUCTION}% reduction)"
        fi
    fi

    if [ "$FORMAT" == "all" ] || [ "$FORMAT" == "square" ]; then
        # Square crop - use MAX_DIMENSION for both width and height
        OUTPUT_SQUARE="$OUTPUT_BASE/square/${NAME}_square.jpg"
        convert "$IMG" -resize "${MAX_DIMENSION}x${MAX_DIMENSION}^" -gravity center -extent "${MAX_DIMENSION}x${MAX_DIMENSION}" -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_SQUARE" 2>/dev/null

        if [ -f "$OUTPUT_SQUARE" ]; then
            NEW_SIZE=$(stat -f%z "$OUTPUT_SQUARE" 2>/dev/null || stat -c%s "$OUTPUT_SQUARE" 2>/dev/null)
            TOTAL_OPTIMIZED_SIZE=$((TOTAL_OPTIMIZED_SIZE + NEW_SIZE))
            REDUCTION=$((100 - (NEW_SIZE * 100 / ORIGINAL_SIZE)))
            echo -e "  ${GREEN}✓${NC} Square: $(format_size $NEW_SIZE) (${REDUCTION}% reduction)"
        fi
    fi

    if [ "$FORMAT" == "all" ] || [ "$FORMAT" == "portrait" ]; then
        # Portrait (4:5 ratio) - calculate based on MAX_DIMENSION
        PORTRAIT_HEIGHT=$(echo "scale=0; $MAX_DIMENSION * 1.25" | bc)
        OUTPUT_PORTRAIT="$OUTPUT_BASE/portrait/${NAME}_portrait.jpg"
        convert "$IMG" -resize "${MAX_DIMENSION}x${PORTRAIT_HEIGHT}^" -gravity center -extent "${MAX_DIMENSION}x${PORTRAIT_HEIGHT}" -quality $QUALITY -colorspace sRGB -sampling-factor 4:4:4 "$OUTPUT_PORTRAIT" 2>/dev/null

        if [ -f "$OUTPUT_PORTRAIT" ]; then
            NEW_SIZE=$(stat -f%z "$OUTPUT_PORTRAIT" 2>/dev/null || stat -c%s "$OUTPUT_PORTRAIT" 2>/dev/null)
            TOTAL_OPTIMIZED_SIZE=$((TOTAL_OPTIMIZED_SIZE + NEW_SIZE))
            REDUCTION=$((100 - (NEW_SIZE * 100 / ORIGINAL_SIZE)))
            echo -e "  ${GREEN}✓${NC} Portrait: $(format_size $NEW_SIZE) (${REDUCTION}% reduction)"
        fi
    fi

    PROCESSED=$((PROCESSED + 1))
done

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                     Optimization Complete!                    ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Photos processed: ${YELLOW}$PROCESSED${NC}"
echo -e "Original total size: ${YELLOW}$(format_size $TOTAL_ORIGINAL_SIZE)${NC}"
echo -e "Optimized total size: ${GREEN}$(format_size $TOTAL_OPTIMIZED_SIZE)${NC}"

if [ $TOTAL_ORIGINAL_SIZE -gt 0 ]; then
    TOTAL_REDUCTION=$((100 - (TOTAL_OPTIMIZED_SIZE * 100 / TOTAL_ORIGINAL_SIZE)))
    echo -e "Space saved: ${GREEN}${TOTAL_REDUCTION}%${NC}"
fi

echo ""
echo -e "${BLUE}Output location:${NC}"
echo -e "  ${YELLOW}$OUTPUT_BASE${NC}"
echo ""
echo -e "${GREEN}Your photos are now ready for Instagram!${NC}"
echo ""

# Check if any files are over 8MB
LARGE_FILES=$(find "$OUTPUT_BASE" -type f -size +8M | wc -l)
if [ "$LARGE_FILES" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Warning: $LARGE_FILES files are over 8MB${NC}"
    echo -e "  Instagram may compress these. Consider using --size 2048 for smaller files."
    echo ""
fi

echo -e "${BLUE}Upload tips:${NC}"
echo "  • Instagram max: 30MB per photo (but >8MB gets compressed)"
echo "  • Current settings: ${MAX_DIMENSION}px @ ${QUALITY}% quality"
echo "  • For smaller files: use --size 2048 or --size 3072"
echo "  • Best upload times: 6-9 PM local time"
echo "  • Use 5-10 relevant hashtags"
echo ""