#!/bin/bash

# drone-extract-frames.sh - Pull still photos out of drone video
#
# You spot a moment while reviewing a clip — the drone settling on a shot, a
# nice bit of light halfway through — and you want it as a photo. This grabs
# it. You do NOT need an exact timestamp: give it roughly the right time and
# a 4K frame comes out looking good enough to post.
#
# ─── USAGE ───────────────────────────────────────────────────────────────
#
#   ./scripts/drone-extract-frames.sh <clip-number|file> [options]
#
# The clip number is the DJI sequence number — 0669 (or just 669) out of
# DJI_20260718153543_0669_D.MP4. No need to type the whole filename: the
# number is looked up in the current project first, then anywhere under
# $DRONE_DEST. A path to a video file works too. If a number matches more
# than one clip, it lists them and asks for a full path.
#
# ─── PICKING THE TIME ────────────────────────────────────────────────────
#
#   (no option)            Last 5 frames — the default, and usually what you
#                          want: the end of a clip is where the drone has
#                          stopped moving and the shot has settled
#   --at <times>           Roughly when you want it. Comma-separated, and any
#                          of these forms:  12  |  1:23  |  00:01:23.5
#                          Landing a fraction of a second off is fine, so
#                          "--at 1:23" rather than hunting for exact frames
#   --last-frames <n>      Last n frames
#   --last-seconds <s>     Every frame in the final s seconds (~30 per second)
#                          Use when the drone was still moving and you want
#                          options to pick the sharpest from
#   --every <s>            One frame every s seconds through the whole clip —
#                          a contact sheet to find the moment you half-remember
#   --count <n>            n frames spread evenly through the clip
#
# Handy trick: --dry-run lists the timestamps it would grab and writes
# nothing, so you can sanity check before pulling 300 frames.
#
# ─── WHAT COMES OUT ──────────────────────────────────────────────────────
#
# Full video resolution, no downscaling — 4K video gives ~8MP stills, which
# is plenty for Instagram (their max is 4096px on the long edge). Files land
# in the project's PHOTOS/FROM_VIDEO/ named by timestamp:
#
#   DJI_20260718153543_0669_D_t00-00-56-156.jpg   <- 56.156s into the clip
#
# JPEG at quality 2 (~2.5MB for 4K) by default. --png for lossless (~13MB),
# --quality 1 for the best JPEG, --out <dir> to put them somewhere else.
#
# ─── THEN WHAT ───────────────────────────────────────────────────────────
#
#   1. open <project>/PHOTOS/FROM_VIDEO   and pick the keepers
#   2. copy those into PHOTOS/INSTAGRAM/
#   3. ./drone-instagram-optimize.sh --size 3584 --quality 98
#
# A still from video won't be as sharp as a photo the drone actually took —
# it's a single frame of compressed video, so fast movement means motion
# blur. Holding still for a second before ending a clip gives you a much
# better still. If a frame looks soft, pull its neighbours with
# --last-seconds 1 and pick the best of the bunch.
#
# ─── NOTES ───────────────────────────────────────────────────────────────
#
# Needs ffmpeg:  brew install ffmpeg
#
# Frame times come from the video's real packet timestamps, not from the
# container duration — the container usually runs slightly past the last
# picture (56.189s vs a final frame at 56.156s), and seeking into that gap
# returns nothing. This is why "the last frame" works rather than silently
# coming up empty.
#
# HDR clips (HLG / PQ) are tone mapped to SDR automatically, otherwise the
# stills come out grey and washed out. Override with --tonemap / --no-tonemap.
#
# Examples:
#   ./scripts/drone-extract-frames.sh 0669
#   ./scripts/drone-extract-frames.sh 0669 --at 1:23
#   ./scripts/drone-extract-frames.sh 0669 --at 0:05,1:23,00:02:10.5
#   ./scripts/drone-extract-frames.sh 0669 --last-seconds 2
#   ./scripts/drone-extract-frames.sh 0669 --every 5 --dry-run
#   ./scripts/drone-extract-frames.sh 0669 --count 10 --png

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/drone-config.sh"

# Defaults
LAST_FRAMES=5       # used when no other mode is given
AT_TIMES=""
LAST_SECONDS=""
EVERY=""
COUNT=""
MODE=""             # at | last-frames | last-seconds | every | count
EXT="jpg"
QUALITY=2           # ffmpeg -q:v, 1 = best
OUT_DIR=""
TONEMAP="auto"      # auto | on | off
DRY_RUN=false
VIDEO_ARG=""

usage() {
    cat <<EOF
Usage: $0 <video-number|file> [OPTIONS]

Extract still photos from a drone video at specific times.

Video can be a DJI clip number (0669, or just 669) or a path to a file.
Numbers are looked up in the current project first, then in:
  $DEST_BASE

Time options (pick one):
  --last-frames <n>    Last n frames of the clip (DEFAULT: 5)
  --last-seconds <s>   Every frame in the final s seconds
  --at <times>         Roughly when you want the still. Comma-separated.
                       Formats: 12  |  1:23  |  00:01:23.5
                       Near enough is fine — no need for an exact frame.
  --every <s>          One frame every s seconds through the whole clip
  --count <n>          n frames spaced evenly through the whole clip

Output options:
  --png                Lossless PNG instead of JPEG (big files)
  --quality <1-31>     JPEG quality, 1 = best (default: 2)
  --out <dir>          Output directory (default: <project>/PHOTOS/FROM_VIDEO)
  --tonemap            Force HDR -> SDR tone mapping
  --no-tonemap         Never tone map (default is auto-detect from the file)
  --dry-run            Show what would be extracted, write nothing
  --help               Show this message

Examples:
  $0 0669                          # last 5 frames — the money shot at the end
  $0 0669 --last-frames 15
  $0 0669 --last-seconds 2
  $0 0669 --at 0:05,1:23,00:02:10.5
  $0 0669 --every 5                # contact sheet of the whole clip
  $0 0669 --count 10 --png
  $0 ~/Movies/DroneFootage/2026/07-July/2026-07-18_Drone_Footage/VIDEO/RAW/DJI_20260718153543_0669_D.MP4
EOF
}

set_mode() {
    if [ -n "$MODE" ]; then
        echo -e "${RED}Error: --$1 conflicts with --$MODE (pick one time option)${NC}"
        exit 1
    fi
    MODE="$1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --last-frames)
            set_mode "last-frames"; LAST_FRAMES="$2"; shift 2 ;;
        --last-seconds)
            set_mode "last-seconds"; LAST_SECONDS="$2"; shift 2 ;;
        --at)
            set_mode "at"; AT_TIMES="$2"; shift 2 ;;
        --every)
            set_mode "every"; EVERY="$2"; shift 2 ;;
        --count)
            set_mode "count"; COUNT="$2"; shift 2 ;;
        --png)
            EXT="png"; shift ;;
        --quality)
            QUALITY="$2"; shift 2 ;;
        --out)
            OUT_DIR="$2"; shift 2 ;;
        --tonemap)
            TONEMAP="on"; shift ;;
        --no-tonemap)
            TONEMAP="off"; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        --help|-h)
            usage; exit 0 ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Run '$0 --help' for usage"
            exit 1 ;;
        *)
            if [ -n "$VIDEO_ARG" ]; then
                echo -e "${RED}Error: more than one video given ('$VIDEO_ARG' and '$1')${NC}"
                exit 1
            fi
            VIDEO_ARG="$1"; shift ;;
    esac
done

[ -z "$MODE" ] && MODE="last-frames"

if [ -z "$VIDEO_ARG" ]; then
    usage
    exit 1
fi

# Check ffmpeg
if ! command -v ffmpeg &> /dev/null || ! command -v ffprobe &> /dev/null; then
    echo -e "${RED}Error: ffmpeg is not installed${NC}"
    echo "Install with: brew install ffmpeg"
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Locate the video
# ─────────────────────────────────────────────────────────────
find_video() {
    local query="$1"

    if [ -f "$query" ]; then
        echo "$query"
        return 0
    fi

    if ! [[ "$query" =~ ^[0-9]{1,4}$ ]]; then
        return 1
    fi

    local num
    num=$(printf "%04d" "$((10#$query))")

    # Current project first (so you can work inside a folder), then everything
    local roots=()
    [ -d "$PWD/VIDEO" ] && roots+=("$PWD/VIDEO")
    [ -d "$DEST_BASE" ] && roots+=("$DEST_BASE")
    [ ${#roots[@]} -eq 0 ] && return 1

    local matches
    matches=$(find "${roots[@]}" -type f \
        \( -iname "*${num}*.mp4" -o -iname "*${num}*.mov" \) 2>/dev/null | sort -u)

    [ -z "$matches" ] && return 1

    if [ "$(echo "$matches" | wc -l)" -gt 1 ]; then
        echo -e "${RED}Error: clip number $num matches more than one video:${NC}" >&2
        echo "$matches" | sed 's/^/  /' >&2
        echo "" >&2
        echo "Pass the full path of the one you want." >&2
        return 2
    fi

    echo "$matches"
}

VIDEO=$(find_video "$VIDEO_ARG")
FIND_STATUS=$?

if [ $FIND_STATUS -eq 2 ]; then
    exit 1
elif [ $FIND_STATUS -ne 0 ] || [ -z "$VIDEO" ]; then
    echo -e "${RED}Error: no video found for '$VIDEO_ARG'${NC}"
    echo "Searched: $DEST_BASE"
    echo "Give a DJI clip number (e.g. 0669) or a path to a video file."
    exit 1
fi

BASENAME=$(basename "$VIDEO")
NAME="${BASENAME%.*}"

# ─────────────────────────────────────────────────────────────
# Probe the video
# ─────────────────────────────────────────────────────────────
probe() {
    ffprobe -v error -select_streams v:0 -show_entries "$1" \
        -of default=noprint_wrappers=1:nokey=1 "$VIDEO" 2>/dev/null | head -1
}

DURATION=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$VIDEO" 2>/dev/null)
FPS_RAW=$(probe "stream=r_frame_rate")
WIDTH=$(probe "stream=width")
HEIGHT=$(probe "stream=height")
TRANSFER=$(probe "stream=color_transfer")

if [ -z "$DURATION" ] || [ -z "$FPS_RAW" ]; then
    echo -e "${RED}Error: could not read video info from $BASENAME${NC}"
    echo "The file may be corrupt or not a video."
    exit 1
fi

FPS=$(awk -F'/' '{ if (NF==2 && $2>0) printf "%.6f", $1/$2; else printf "%.6f", $1 }' <<< "$FPS_RAW")

# HDR (HLG / PQ) footage extracts washed-out unless tone mapped to SDR
DO_TONEMAP=false
if [ "$TONEMAP" == "on" ]; then
    DO_TONEMAP=true
elif [ "$TONEMAP" == "auto" ]; then
    case "$TRANSFER" in
        arib-std-b67|smpte2084) DO_TONEMAP=true ;;
    esac
fi

# ─────────────────────────────────────────────────────────────
# Time helpers
# ─────────────────────────────────────────────────────────────

# "1:23.5" / "00:01:23" / "12" -> seconds as float
parse_time() {
    awk -F: '{
        s = 0
        for (i = 1; i <= NF; i++) s = s * 60 + $i
        printf "%.3f", s
    }' <<< "$1"
}

# 83.456 -> 00-01-23-456  (safe for filenames, still readable)
time_tag() {
    awk -v t="$1" 'BEGIN {
        h = int(t / 3600); m = int((t - h * 3600) / 60)
        s = int(t - h * 3600 - m * 60)
        ms = int((t - int(t)) * 1000 + 0.5)
        printf "%02d-%02d-%02d-%03d", h, m, s, ms
    }'
}

# 83.456 -> 00:01:23.456  (for display)
time_pretty() {
    awk -v t="$1" 'BEGIN {
        h = int(t / 3600); m = int((t - h * 3600) / 60)
        s = t - h * 3600 - m * 60
        printf "%02d:%02d:%06.3f", h, m, s
    }'
}

# Real frame timestamps from <start> to the end of the clip, in display order.
# Container duration usually runs past the last video frame, so computing frame
# times from duration alone asks ffmpeg to seek past EOF and gets nothing back.
# Reading packet timestamps is exact and costs no decoding.
frame_times_from() {
    local start
    start=$(awk -v s="$1" 'BEGIN { if (s < 0) s = 0; printf "%.3f", s }')
    ffprobe -v error -select_streams v:0 -read_intervals "${start}%" \
        -show_entries packet=pts_time -of csv=p=0 "$VIDEO" 2>/dev/null \
        | tr -d ',' | grep -E '^[0-9]' | sort -n
}

# Timestamp of the final frame — the real end of the picture
LAST_T=""
for window in 2 10 60; do
    LAST_T=$(frame_times_from "$(awk -v d="$DURATION" -v w="$window" \
        'BEGIN { printf "%.3f", d - w }')" | tail -1)
    [ -n "$LAST_T" ] && break
done
if [ -z "$LAST_T" ]; then
    # Fall back to duration maths if packet timestamps are unreadable
    LAST_T=$(awk -v d="$DURATION" -v fps="$FPS" 'BEGIN { printf "%.3f", d - 1 / fps }')
fi

# ─────────────────────────────────────────────────────────────
# Build the list of times to grab
# ─────────────────────────────────────────────────────────────
TIMES=()

case "$MODE" in
    at)
        IFS=',' read -ra RAW_TIMES <<< "$AT_TIMES"
        for t in "${RAW_TIMES[@]}"; do
            t=$(echo "$t" | tr -d ' ')
            [ -z "$t" ] && continue
            if ! [[ "$t" =~ ^[0-9]+(:[0-9]+)*(\.[0-9]+)?$ ]]; then
                echo -e "${RED}Error: '$t' is not a timestamp (use 12, 1:23 or 00:01:23.5)${NC}"
                exit 1
            fi
            secs=$(parse_time "$t")
            if awk -v s="$secs" -v l="$LAST_T" 'BEGIN { exit !(s > l) }'; then
                echo -e "${YELLOW}⚠ Skipping $t — past the end of the clip ($(time_pretty "$LAST_T"))${NC}"
                continue
            fi
            TIMES+=("$secs")
        done
        ;;

    last-frames)
        if ! [[ "$LAST_FRAMES" =~ ^[0-9]+$ ]] || [ "$LAST_FRAMES" -lt 1 ]; then
            echo -e "${RED}Error: --last-frames needs a positive whole number${NC}"
            exit 1
        fi
        # Real timestamps of the last n frames
        SCAN=$(awk -v n="$LAST_FRAMES" -v fps="$FPS" 'BEGIN {
            w = n / fps * 1.5 + 1; if (w < 2) w = 2; printf "%.3f", w
        }')
        while read -r t; do TIMES+=("$t"); done < <(
            frame_times_from "$(awk -v d="$DURATION" -v w="$SCAN" \
                'BEGIN { printf "%.3f", d - w }')" | tail -n "$LAST_FRAMES"
        )
        ;;

    last-seconds)
        if ! [[ "$LAST_SECONDS" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo -e "${RED}Error: --last-seconds needs a number${NC}"
            exit 1
        fi
        CUTOFF=$(awk -v l="$LAST_T" -v w="$LAST_SECONDS" 'BEGIN { printf "%.3f", l - w }')
        while read -r t; do TIMES+=("$t"); done < <(
            frame_times_from "$CUTOFF" \
                | awk -v c="$CUTOFF" '$1 >= c - 0.0001'
        )
        ;;

    every)
        if ! [[ "$EVERY" =~ ^[0-9]+(\.[0-9]+)?$ ]] || awk -v e="$EVERY" 'BEGIN { exit !(e <= 0) }'; then
            echo -e "${RED}Error: --every needs a positive number of seconds${NC}"
            exit 1
        fi
        while read -r t; do TIMES+=("$t"); done < <(
            awk -v last="$LAST_T" -v step="$EVERY" 'BEGIN {
                for (t = 0; t <= last; t += step) printf "%.3f\n", t
            }'
        )
        ;;

    count)
        if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ]; then
            echo -e "${RED}Error: --count needs a positive whole number${NC}"
            exit 1
        fi
        while read -r t; do TIMES+=("$t"); done < <(
            awk -v last="$LAST_T" -v n="$COUNT" 'BEGIN {
                if (n == 1) { printf "%.3f\n", last / 2; exit }
                for (i = 0; i < n; i++) printf "%.3f\n", i * last / (n - 1)
            }'
        )
        ;;
esac

if [ ${#TIMES[@]} -eq 0 ]; then
    echo -e "${RED}Error: nothing to extract${NC}"
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Output location
# ─────────────────────────────────────────────────────────────
if [ -z "$OUT_DIR" ]; then
    # <project>/VIDEO/RAW/clip.mp4  ->  <project>/PHOTOS/FROM_VIDEO
    VIDEO_DIR=$(cd "$(dirname "$VIDEO")" && pwd)
    PROJECT_DIR="$VIDEO_DIR"
    while [ "$PROJECT_DIR" != "/" ]; do
        if [ -d "$PROJECT_DIR/PHOTOS" ] || [ -d "$PROJECT_DIR/VIDEO" ]; then
            break
        fi
        PROJECT_DIR=$(dirname "$PROJECT_DIR")
    done

    if [ "$PROJECT_DIR" == "/" ]; then
        OUT_DIR="$VIDEO_DIR/FROM_VIDEO"
    else
        OUT_DIR="$PROJECT_DIR/PHOTOS/FROM_VIDEO"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Report
# ─────────────────────────────────────────────────────────────
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              Extract Photos From Drone Video                  ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Video:      ${YELLOW}$BASENAME${NC}"
echo -e "Resolution: ${YELLOW}${WIDTH}x${HEIGHT}${NC} @ ${YELLOW}$(awk -v f="$FPS" 'BEGIN{printf "%.2f", f}') fps${NC}"
echo -e "Duration:   ${YELLOW}$(time_pretty "$DURATION")${NC}"
if [ "$DO_TONEMAP" = true ]; then
    echo -e "Colour:     ${YELLOW}HDR ($TRANSFER) → tone mapping to SDR${NC}"
fi
echo -e "Frames:     ${YELLOW}${#TIMES[@]}${NC} (mode: $MODE)"
echo -e "Output:     ${YELLOW}$OUT_DIR${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Dry run — would extract:${NC}"
    for t in "${TIMES[@]}"; do
        echo "  $(time_pretty "$t")  →  ${NAME}_t$(time_tag "$t").${EXT}"
    done
    echo ""
    exit 0
fi

mkdir -p "$OUT_DIR"

# ─────────────────────────────────────────────────────────────
# Extract
# ─────────────────────────────────────────────────────────────
if [ "$DO_TONEMAP" = true ]; then
    VF="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv"
else
    VF=""
fi

if [ "$EXT" == "png" ]; then
    ENCODE_ARGS=(-compression_level 1)
else
    ENCODE_ARGS=(-q:v "$QUALITY")
fi

echo -e "${BLUE}Extracting...${NC}"
echo "────────────────────────────────────────────────────────────────"

EXTRACTED=0
FAILED=0
TOTAL_SIZE=0

for t in "${TIMES[@]}"; do
    OUTPUT="$OUT_DIR/${NAME}_t$(time_tag "$t").${EXT}"

    FF_ARGS=(-y -ss "$t" -i "$VIDEO" -frames:v 1)
    [ -n "$VF" ] && FF_ARGS+=(-vf "$VF")
    FF_ARGS+=("${ENCODE_ARGS[@]}" "$OUTPUT")

    if ffmpeg "${FF_ARGS[@]}" 2>/dev/null && [ -s "$OUTPUT" ]; then
        SIZE=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        EXTRACTED=$((EXTRACTED + 1))
        printf "  ${GREEN}✓${NC} %s  →  %s (%s KB)\n" \
            "$(time_pretty "$t")" "$(basename "$OUTPUT")" "$((SIZE / 1024))"
    else
        rm -f "$OUTPUT"
        FAILED=$((FAILED + 1))
        echo -e "  ${RED}✗${NC} $(time_pretty "$t") — no frame extracted"
    fi
done

echo "────────────────────────────────────────────────────────────────"
echo ""
echo -e "${GREEN}Extracted $EXTRACTED photo(s)${NC} ($((TOTAL_SIZE / 1024 / 1024)) MB total)"
[ "$FAILED" -gt 0 ] && echo -e "${YELLOW}$FAILED frame(s) failed${NC}"
echo -e "Saved to: ${YELLOW}$OUT_DIR${NC}"
echo ""

if [ "$EXTRACTED" -gt 0 ]; then
    echo -e "${BLUE}Next steps:${NC}"
    echo "  • Review:    open \"$OUT_DIR\""
    echo "  • Instagram: copy the keepers into PHOTOS/INSTAGRAM/ then run"
    echo "               ./drone-instagram-optimize.sh --size 3584 --quality 98"
    echo ""
    echo -e "${BLUE}Tip:${NC} video frames are ~${WIDTH}x${HEIGHT} (~$((WIDTH * HEIGHT / 1000000)) MP)."
    echo "     Pick the sharpest one — pull a few frames either side with"
    echo "     --last-seconds 1 if the drone was moving."
    echo ""
fi
