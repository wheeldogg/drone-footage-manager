#!/bin/bash

# wheeldogg-video-creator.sh - Multi-Platform Video Generator
# Creates YouTube full video, Instagram clip, and YouTube Short from drone footage
# Usage: ./scripts/wheeldogg-video-creator.sh [--project <folder>] [options]

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_msg() {
    echo -e "${1}${2}${NC}"
}

# Default settings
PHOTO_DURATION=4          # Seconds per photo
TRANSITION_DURATION=1     # Crossfade duration
OUTPUT_DIR=""             # Output directory (auto-set)
OUTPUT_FILE=""            # Legacy: single output file
TEMP_DIR="/tmp/wheeldogg_$$"
RESOLUTION="1920x1080"    # Output resolution (WxH format for display)
RES_WIDTH=1920            # Resolution width for ffmpeg
RES_HEIGHT=1080           # Resolution height for ffmpeg
FPS=30
PROJECT_DIR=""            # Project directory for auto-detection
FORMATS="all"             # Which outputs to generate
SHORT_DURATION=60         # Duration for Instagram/Short clips
LEGACY_MODE=false         # Single output file mode
SKIP_PHOTOS=false         # Skip photo processing

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --videos)
            VIDEO_DIR="$2"
            shift 2
            ;;
        --photos)
            PHOTO_DIR="$2"
            shift 2
            ;;
        --music)
            MUSIC_FILE="$2"
            shift 2
            ;;
        --output)
            # Check if output is a file (.mp4) or directory
            if [[ "$2" == *.mp4 ]]; then
                OUTPUT_FILE="$2"
                LEGACY_MODE=true
            else
                OUTPUT_DIR="$2"
            fi
            shift 2
            ;;
        --formats)
            FORMATS="$2"
            shift 2
            ;;
        --short-duration)
            SHORT_DURATION="$2"
            shift 2
            ;;
        --no-photos|--videos-only)
            SKIP_PHOTOS=true
            shift
            ;;
        --photo-duration)
            PHOTO_DURATION="$2"
            shift 2
            ;;
        --resolution)
            RESOLUTION="$2"
            # Parse WxH format into separate width/height
            RES_WIDTH="${2%x*}"
            RES_HEIGHT="${2#*x}"
            shift 2
            ;;
        --help)
            print_msg $CYAN "═══════════════════════════════════════════════════════════════"
            print_msg $CYAN "     wheeldogg Video Creator - Multi-Platform Video Generator   "
            print_msg $CYAN "═══════════════════════════════════════════════════════════════"
            echo ""
            print_msg $YELLOW "SIMPLE USAGE (auto-detect folders):"
            echo "  $0"
            echo "  $0 --project \"/path/to/project\""
            echo ""
            print_msg $YELLOW "ADVANCED USAGE:"
            echo "  $0 --videos VIDEOS/ --photos PHOTOS/ --music track.mp3"
            echo ""
            print_msg $YELLOW "REQUIRED FOLDER STRUCTURE:"
            echo "  PROJECT/"
            echo "  ├── VIDEOS/    Video clips (mp4, mov)"
            echo "  ├── PHOTOS/    Photos for Ken Burns effect (jpg, png)"
            echo "  └── MUSIC/     Single music file (mp3, wav)"
            echo ""
            print_msg $YELLOW "OPTIONS:"
            echo "  --project <folder>      Project folder (default: current directory)"
            echo "  --videos <folder>       Video clips folder"
            echo "  --photos <folder>       Photos folder"
            echo "  --music <file|folder>   Music file or MUSIC/ folder"
            echo "  --output <folder|file>  Output folder or file (default: OUTPUT/)"
            echo "  --formats <list>        Outputs: youtube, instagram, short, all (default: all)"
            echo "  --short-duration <sec>  Short clip duration (default: 60)"
            echo "  --no-photos             Skip photos, use only video clips"
            echo "  --photo-duration <sec>  Seconds per photo (default: 4)"
            echo "  --resolution <WxH>      Output resolution (default: 1920x1080)"
            echo "  --help                  Show this help"
            echo ""
            print_msg $YELLOW "OUTPUTS GENERATED:"
            echo "  OUTPUT/"
            echo "  ├── wheeldogg_youtube.mp4     1920x1080, full music duration"
            echo "  ├── wheeldogg_instagram.mp4   1920x1080, 60 seconds, landscape"
            echo "  └── wheeldogg_short.mp4       1080x1920, 60 seconds, vertical (9:16)"
            echo ""
            print_msg $YELLOW "FEATURES:"
            echo "  - Videos play forward + reversed (doubles footage)"
            echo "  - Photos get Ken Burns effect (zoom in/out, pan left/right)"
            echo "  - Content loops if shorter than music"
            echo "  - Crossfade transitions between clips"
            echo "  - Audio fade-out on short clips"
            echo ""
            print_msg $GREEN "EXAMPLES:"
            echo "  # Simple: run from project folder"
            echo "  cd MyDroneProject && ~/scripts/wheeldogg-video-creator.sh"
            echo ""
            echo "  # Generate only YouTube Short"
            echo "  $0 --formats short"
            echo ""
            echo "  # Custom short duration (45 seconds)"
            echo "  $0 --short-duration 45"
            echo ""
            echo "  # Legacy mode (single output)"
            echo "  $0 --videos V/ --photos P/ --music m.mp3 --output out.mp4"
            exit 0
            ;;
        *)
            print_msg $RED "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Auto-detect project directory
if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(pwd)"
fi

# Auto-detect folders if not explicitly provided
auto_detect_folders() {
    # Detect VIDEO folder (check nested folders too)
    if [ -z "$VIDEO_DIR" ]; then
        # First check for direct VIDEO/VIDEOS folder
        for folder in "VIDEO" "VIDEOS" "video" "videos"; do
            if [ -d "$PROJECT_DIR/$folder" ]; then
                VIDEO_DIR="$PROJECT_DIR/$folder"
                # Check for nested "USE THESE" or similar subfolder
                for subfolder in "USE THESE" "USE_THESE" "SELECTED" "FINAL"; do
                    if [ -d "$VIDEO_DIR/$subfolder" ]; then
                        VIDEO_DIR="$VIDEO_DIR/$subfolder"
                        print_msg $GREEN "  Auto-detected videos: $folder/$subfolder/"
                        break 2
                    fi
                done
                print_msg $GREEN "  Auto-detected videos: $folder/"
                break
            fi
        done
    fi

    # Detect PHOTO folder (check nested folders too)
    if [ -z "$PHOTO_DIR" ]; then
        for folder in "PHOTOS" "PHOTO" "photos" "photo"; do
            if [ -d "$PROJECT_DIR/$folder" ]; then
                # Check for nested INSTAGRAM or similar subfolder first
                for subfolder in "INSTAGRAM" "USE THESE" "USE_THESE" "SELECTED" "FINAL"; do
                    if [ -d "$PROJECT_DIR/$folder/$subfolder" ]; then
                        PHOTO_DIR="$PROJECT_DIR/$folder/$subfolder"
                        print_msg $GREEN "  Auto-detected photos: $folder/$subfolder/"
                        break 2
                    fi
                done
                # Fall back to main folder
                PHOTO_DIR="$PROJECT_DIR/$folder"
                print_msg $GREEN "  Auto-detected photos: $folder/"
                break
            fi
        done
        # Also check for standalone INSTAGRAM folder
        if [ -z "$PHOTO_DIR" ] && [ -d "$PROJECT_DIR/INSTAGRAM" ]; then
            PHOTO_DIR="$PROJECT_DIR/INSTAGRAM"
            print_msg $GREEN "  Auto-detected photos: INSTAGRAM/"
        fi
    fi

    # Detect MUSIC file
    if [ -z "$MUSIC_FILE" ]; then
        # Check for MUSIC folder first
        for folder in "MUSIC" "music" "AUDIO" "audio"; do
            if [ -d "$PROJECT_DIR/$folder" ]; then
                # Find first audio file in folder
                for ext in mp3 MP3 wav WAV m4a M4A aac AAC; do
                    FOUND=$(find "$PROJECT_DIR/$folder" -maxdepth 1 -name "*.$ext" -type f | head -1)
                    if [ -n "$FOUND" ]; then
                        MUSIC_FILE="$FOUND"
                        print_msg $GREEN "  Auto-detected music: $(basename "$MUSIC_FILE")"
                        break 2
                    fi
                done
            fi
        done
    fi

    # Set default output directory
    if [ -z "$OUTPUT_DIR" ] && [ "$LEGACY_MODE" = false ]; then
        OUTPUT_DIR="$PROJECT_DIR/OUTPUT"
    fi
}

print_msg $CYAN "═══════════════════════════════════════════════════════════════"
print_msg $CYAN "     wheeldogg Video Creator - Multi-Platform Video Generator   "
print_msg $CYAN "═══════════════════════════════════════════════════════════════"
echo ""

print_msg $BLUE "Scanning project folder..."
auto_detect_folders
echo ""

# Validate inputs
if [ -z "$MUSIC_FILE" ]; then
    print_msg $RED "Error: No music file found"
    echo "Create a MUSIC/ folder with your audio file, or use --music <file>"
    exit 1
fi

if [ ! -f "$MUSIC_FILE" ]; then
    print_msg $RED "Error: Music file not found: $MUSIC_FILE"
    exit 1
fi

if [ -z "$VIDEO_DIR" ] && [ -z "$PHOTO_DIR" ]; then
    print_msg $RED "Error: No VIDEOS/ or PHOTOS/ folder found"
    echo "Create at least one of these folders with your content"
    exit 1
fi

# Check ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    print_msg $RED "Error: ffmpeg is not installed"
    echo "Install with: brew install ffmpeg"
    exit 1
fi

# Create temp and output directories
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

if [ "$LEGACY_MODE" = false ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Get music duration
print_msg $BLUE "Analyzing music..."
MUSIC_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MUSIC_FILE" 2>/dev/null)
MUSIC_DURATION_INT=${MUSIC_DURATION%.*}
print_msg $GREEN "  Music duration: ${MUSIC_DURATION_INT}s ($(echo "scale=1; $MUSIC_DURATION_INT/60" | bc)m)"
echo ""

# Collect and process videos
CLIP_LIST=""
CLIP_COUNT=0
TOTAL_DURATION=0

if [ -n "$VIDEO_DIR" ] && [ -d "$VIDEO_DIR" ]; then
    print_msg $BLUE "Processing videos..."

    shopt -s nullglob
    for VIDEO in "$VIDEO_DIR"/*.mp4 "$VIDEO_DIR"/*.MP4 "$VIDEO_DIR"/*.mov "$VIDEO_DIR"/*.MOV; do
        [ -f "$VIDEO" ] || continue

        BASENAME=$(basename "$VIDEO")
        print_msg $YELLOW "  Processing: $BASENAME"

        # Get video duration
        VID_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO" 2>/dev/null)
        VID_DURATION_INT=${VID_DURATION%.*}

        # Create forward clip (scaled to resolution, no audio)
        FORWARD_CLIP="$TEMP_DIR/clip_${CLIP_COUNT}_forward.mp4"
        FORWARD_LOG="$TEMP_DIR/forward_${CLIP_COUNT}.log"
        ffmpeg -y -i "$VIDEO" -vf "scale=${RES_WIDTH}:${RES_HEIGHT}:force_original_aspect_ratio=decrease,pad=${RES_WIDTH}:${RES_HEIGHT}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$FPS" -an -c:v libx264 -preset fast -crf 23 "$FORWARD_CLIP" 2>"$FORWARD_LOG"

        if [ -f "$FORWARD_CLIP" ] && [ -s "$FORWARD_CLIP" ]; then
            CLIP_LIST="$CLIP_LIST $FORWARD_CLIP"
            CLIP_COUNT=$((CLIP_COUNT + 1))
            TOTAL_DURATION=$((TOTAL_DURATION + VID_DURATION_INT))
            print_msg $GREEN "    Forward: ${VID_DURATION_INT}s"
        else
            print_msg $RED "    Forward encoding failed!"
            tail -5 "$FORWARD_LOG"
        fi

        # Create reversed clip (can be memory intensive for long 4K videos)
        REVERSE_CLIP="$TEMP_DIR/clip_${CLIP_COUNT}_reverse.mp4"
        REVERSE_LOG="$TEMP_DIR/reverse_${CLIP_COUNT}.log"
        print_msg $YELLOW "    Creating reversed clip (this may take a moment)..."
        ffmpeg -y -i "$VIDEO" -vf "scale=${RES_WIDTH}:${RES_HEIGHT}:force_original_aspect_ratio=decrease,pad=${RES_WIDTH}:${RES_HEIGHT}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$FPS,reverse" -an -c:v libx264 -preset fast -crf 23 "$REVERSE_CLIP" 2>"$REVERSE_LOG"

        if [ -f "$REVERSE_CLIP" ] && [ -s "$REVERSE_CLIP" ]; then
            CLIP_LIST="$CLIP_LIST $REVERSE_CLIP"
            CLIP_COUNT=$((CLIP_COUNT + 1))
            TOTAL_DURATION=$((TOTAL_DURATION + VID_DURATION_INT))
            print_msg $GREEN "    Reversed: ${VID_DURATION_INT}s"
        else
            print_msg $RED "    Reverse encoding failed!"
            tail -5 "$REVERSE_LOG"
        fi
    done
    echo ""
fi

# Process photos with Ken Burns effect
if [ "$SKIP_PHOTOS" = true ]; then
    print_msg $YELLOW "Skipping photos (--no-photos flag set)"
elif [ -n "$PHOTO_DIR" ] && [ -d "$PHOTO_DIR" ]; then
    print_msg $BLUE "Processing photos (Ken Burns effect)..."

    PHOTO_COUNT=0
    for PHOTO in "$PHOTO_DIR"/*.jpg "$PHOTO_DIR"/*.JPG "$PHOTO_DIR"/*.jpeg "$PHOTO_DIR"/*.JPEG "$PHOTO_DIR"/*.png "$PHOTO_DIR"/*.PNG; do
        [ -f "$PHOTO" ] || continue

        BASENAME=$(basename "$PHOTO")

        # Alternate between different Ken Burns effects
        EFFECT_TYPE=$((PHOTO_COUNT % 4))

        PHOTO_CLIP="$TEMP_DIR/photo_${CLIP_COUNT}.mp4"

        case $EFFECT_TYPE in
            0) # Zoom in from center
                ZOOM_FILTER="zoompan=z='min(zoom+0.0015,1.3)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=$((PHOTO_DURATION * FPS)):s=$RESOLUTION:fps=$FPS"
                ;;
            1) # Zoom out from center
                ZOOM_FILTER="zoompan=z='if(lte(zoom,1.0),1.3,max(1.001,zoom-0.0015))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=$((PHOTO_DURATION * FPS)):s=$RESOLUTION:fps=$FPS"
                ;;
            2) # Pan left to right
                ZOOM_FILTER="zoompan=z='1.2':x='if(lte(on,1),0,min(iw/zoom-iw,x+2))':y='ih/2-(ih/zoom/2)':d=$((PHOTO_DURATION * FPS)):s=$RESOLUTION:fps=$FPS"
                ;;
            3) # Pan right to left
                ZOOM_FILTER="zoompan=z='1.2':x='if(lte(on,1),iw/zoom-iw,max(0,x-2))':y='ih/2-(ih/zoom/2)':d=$((PHOTO_DURATION * FPS)):s=$RESOLUTION:fps=$FPS"
                ;;
        esac

        ffmpeg -y -loop 1 -i "$PHOTO" -vf "$ZOOM_FILTER,format=yuv420p" -t $PHOTO_DURATION -c:v libx264 -preset fast -crf 23 "$PHOTO_CLIP" 2>/dev/null

        if [ -f "$PHOTO_CLIP" ]; then
            CLIP_LIST="$CLIP_LIST $PHOTO_CLIP"
            CLIP_COUNT=$((CLIP_COUNT + 1))
            TOTAL_DURATION=$((TOTAL_DURATION + PHOTO_DURATION))
            PHOTO_COUNT=$((PHOTO_COUNT + 1))
            print_msg $GREEN "  $BASENAME (effect $((EFFECT_TYPE + 1)))"
        fi
    done
    echo ""
fi

if [ $CLIP_COUNT -eq 0 ]; then
    print_msg $RED "Error: No clips created. Check your video/photo folders."
    exit 1
fi

print_msg $BLUE "Clips prepared: $CLIP_COUNT"
print_msg $BLUE "Total content duration: ${TOTAL_DURATION}s"
print_msg $BLUE "Music duration: ${MUSIC_DURATION_INT}s"
echo ""

# Calculate if we need to loop content
if [ $TOTAL_DURATION -lt $MUSIC_DURATION_INT ]; then
    LOOPS_NEEDED=$(echo "scale=0; ($MUSIC_DURATION_INT / $TOTAL_DURATION) + 1" | bc)
    print_msg $YELLOW "Content shorter than music - will loop ${LOOPS_NEEDED}x"
fi

# Create concat file
print_msg $BLUE "Combining clips..."
CONCAT_FILE="$TEMP_DIR/concat.txt"
> "$CONCAT_FILE"

# Add clips to concat file, looping if needed
CURRENT_DURATION=0
while [ $CURRENT_DURATION -lt $MUSIC_DURATION_INT ]; do
    for CLIP in $CLIP_LIST; do
        if [ $CURRENT_DURATION -ge $MUSIC_DURATION_INT ]; then
            break
        fi
        echo "file '$CLIP'" >> "$CONCAT_FILE"
        CLIP_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$CLIP" 2>/dev/null)
        CLIP_DUR_INT=${CLIP_DUR%.*}
        CURRENT_DURATION=$((CURRENT_DURATION + CLIP_DUR_INT))
    done
done

# Concatenate all clips
COMBINED_VIDEO="$TEMP_DIR/combined.mp4"
FFMPEG_LOG="$TEMP_DIR/ffmpeg_concat.log"
ffmpeg -y -f concat -safe 0 -i "$CONCAT_FILE" -c:v libx264 -preset fast -crf 23 "$COMBINED_VIDEO" 2>"$FFMPEG_LOG"

if [ ! -f "$COMBINED_VIDEO" ]; then
    print_msg $RED "Error: Failed to combine clips"
    print_msg $YELLOW "Debug: Concat file contents:"
    cat "$CONCAT_FILE" 2>/dev/null | head -5
    print_msg $YELLOW "Debug: FFmpeg error:"
    tail -20 "$FFMPEG_LOG" 2>/dev/null
    exit 1
fi

print_msg $GREEN "  Clips combined"

# ═══════════════════════════════════════════════════════════════
# OUTPUT GENERATION
# ═══════════════════════════════════════════════════════════════

echo ""
print_msg $CYAN "═══════════════════════════════════════════════════════════════"
print_msg $CYAN "                    Generating Outputs                          "
print_msg $CYAN "═══════════════════════════════════════════════════════════════"
echo ""

# Legacy mode: single output file
if [ "$LEGACY_MODE" = true ]; then
    print_msg $BLUE "Creating video (legacy mode)..."
    ffmpeg -y -i "$COMBINED_VIDEO" -i "$MUSIC_FILE" -t "$MUSIC_DURATION" -map 0:v -map 1:a -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 192k -shortest "$OUTPUT_FILE" 2>/dev/null

    if [ -f "$OUTPUT_FILE" ]; then
        OUTPUT_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        FINAL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE" 2>/dev/null)
        FINAL_DURATION_INT=${FINAL_DURATION%.*}

        echo ""
        print_msg $GREEN "═══════════════════════════════════════════════════════════════"
        print_msg $GREEN "                    Video Created Successfully!                "
        print_msg $GREEN "═══════════════════════════════════════════════════════════════"
        echo ""
        print_msg $NC "Output: $OUTPUT_FILE"
        print_msg $NC "Duration: ${FINAL_DURATION_INT}s ($(echo "scale=1; $FINAL_DURATION_INT/60" | bc) minutes)"
        print_msg $NC "Size: $OUTPUT_SIZE"
        print_msg $NC "Resolution: $RESOLUTION"
    else
        print_msg $RED "Error: Failed to create final video"
        exit 1
    fi
    exit 0
fi

# Multi-output mode
YOUTUBE_FILE="$OUTPUT_DIR/wheeldogg_youtube.mp4"
INSTAGRAM_FILE="$OUTPUT_DIR/wheeldogg_instagram.mp4"
SHORT_FILE="$OUTPUT_DIR/wheeldogg_short.mp4"

# ─────────────────────────────────────────────────────────────────
# 1. YOUTUBE FULL VIDEO (1920x1080, full music duration)
# ─────────────────────────────────────────────────────────────────
if [ "$FORMATS" = "all" ] || [ "$FORMATS" = "youtube" ]; then
    print_msg $BLUE "Creating YouTube full video (1920x1080, ${MUSIC_DURATION_INT}s)..."

    ffmpeg -y -i "$COMBINED_VIDEO" -i "$MUSIC_FILE" \
        -t "$MUSIC_DURATION" \
        -map 0:v -map 1:a \
        -c:v libx264 -preset fast -crf 23 \
        -c:a aac -b:a 192k \
        -shortest \
        "$YOUTUBE_FILE" 2>/dev/null

    if [ -f "$YOUTUBE_FILE" ]; then
        YT_SIZE=$(du -h "$YOUTUBE_FILE" | cut -f1)
        YT_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$YOUTUBE_FILE" 2>/dev/null)
        YT_DURATION_INT=${YT_DURATION%.*}
        print_msg $GREEN "  YouTube: ${YT_DURATION_INT}s, $YT_SIZE"
    else
        print_msg $RED "  Failed to create YouTube video"
    fi
fi

# ─────────────────────────────────────────────────────────────────
# 2. INSTAGRAM CLIP (1920x1080, 60 seconds with audio fade)
# ─────────────────────────────────────────────────────────────────
if [ "$FORMATS" = "all" ] || [ "$FORMATS" = "instagram" ]; then
    print_msg $BLUE "Creating Instagram clip (1920x1080, ${SHORT_DURATION}s)..."

    # Calculate fade start (3 seconds before end)
    FADE_START=$((SHORT_DURATION - 3))

    ffmpeg -y -i "$COMBINED_VIDEO" -i "$MUSIC_FILE" \
        -t "$SHORT_DURATION" \
        -map 0:v -map 1:a \
        -af "afade=t=out:st=${FADE_START}:d=3" \
        -c:v libx264 -preset fast -crf 23 \
        -c:a aac -b:a 192k \
        "$INSTAGRAM_FILE" 2>/dev/null

    if [ -f "$INSTAGRAM_FILE" ]; then
        IG_SIZE=$(du -h "$INSTAGRAM_FILE" | cut -f1)
        print_msg $GREEN "  Instagram: ${SHORT_DURATION}s, $IG_SIZE"
    else
        print_msg $RED "  Failed to create Instagram clip"
    fi
fi

# ─────────────────────────────────────────────────────────────────
# 3. YOUTUBE SHORT (1080x1920 vertical, 60 seconds)
# ─────────────────────────────────────────────────────────────────
if [ "$FORMATS" = "all" ] || [ "$FORMATS" = "short" ]; then
    print_msg $BLUE "Creating YouTube Short (1080x1920 vertical, ${SHORT_DURATION}s)..."

    # Calculate fade start (3 seconds before end)
    FADE_START=$((SHORT_DURATION - 3))

    # Center crop from 16:9 to 9:16
    # crop=ih*9/16:ih crops to square-ish portion, then scale to 1080x1920
    ffmpeg -y -i "$COMBINED_VIDEO" -i "$MUSIC_FILE" \
        -t "$SHORT_DURATION" \
        -map 0:v -map 1:a \
        -vf "crop=ih*9/16:ih,scale=1080:1920,setsar=1" \
        -af "afade=t=out:st=${FADE_START}:d=3" \
        -c:v libx264 -preset fast -crf 23 \
        -c:a aac -b:a 192k \
        "$SHORT_FILE" 2>/dev/null

    if [ -f "$SHORT_FILE" ]; then
        SHORT_SIZE=$(du -h "$SHORT_FILE" | cut -f1)
        print_msg $GREEN "  YouTube Short: ${SHORT_DURATION}s, $SHORT_SIZE (vertical)"
    else
        print_msg $RED "  Failed to create YouTube Short"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

echo ""
print_msg $GREEN "═══════════════════════════════════════════════════════════════"
print_msg $GREEN "                    Videos Created Successfully!               "
print_msg $GREEN "═══════════════════════════════════════════════════════════════"
echo ""

print_msg $CYAN "Output folder: $OUTPUT_DIR"
echo ""

if [ -f "$YOUTUBE_FILE" ]; then
    print_msg $NC "  YouTube Full:    wheeldogg_youtube.mp4"
    print_msg $NC "                   1920x1080, $(echo "scale=1; $YT_DURATION_INT/60" | bc) min, $YT_SIZE"
fi

if [ -f "$INSTAGRAM_FILE" ]; then
    print_msg $NC "  Instagram Clip:  wheeldogg_instagram.mp4"
    print_msg $NC "                   1920x1080, ${SHORT_DURATION}s, $IG_SIZE"
fi

if [ -f "$SHORT_FILE" ]; then
    print_msg $NC "  YouTube Short:   wheeldogg_short.mp4"
    print_msg $NC "                   1080x1920 (vertical), ${SHORT_DURATION}s, $SHORT_SIZE"
fi

echo ""
print_msg $CYAN "Content used:"
print_msg $NC "  Videos: Forward + Reversed versions"
print_msg $NC "  Photos: Ken Burns effect (zoom/pan)"
print_msg $NC "  Music: $(basename "$MUSIC_FILE")"
echo ""
print_msg $GREEN "Ready to upload to wheeldogg channels!"
