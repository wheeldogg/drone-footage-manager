#!/bin/bash

# drone-cut-clips.sh - Trim clips from drone videos and combine them
#
# You review a shoot, note the good bits ("45s in on 0649 to the end, and
# reverse it"), and this cuts exactly those pieces and stitches them into a
# montage. It's the manual-edit counterpart to wheeldogg-video-creator.sh:
# that one uses whole clips + music; this one uses precise in/out points and
# needs no music (drone clips have no audio anyway).
#
# ─── USAGE ───────────────────────────────────────────────────────────────
#
#   ./scripts/drone-cut-clips.sh [--project <folder>] [--cuts <file>] [options]
#
# Reads a cuts spec (default: <project>/CLIPS.txt) and for each line:
#   • trims that piece out of VIDEO/RAW/ at full 4K quality  -> VIDEO/CLIPS/
#   • if marked 'reverse', also writes a reversed version
# Then, unless --no-combine, builds montages into OUTPUT/:
#   • combined_clips.mp4         all cuts in order (reverses played inline)
#   • combined_clips_photos.mp4  the above, then the INSTAGRAM photos with a
#                                slow Ken Burns move (skipped if no photos)
#
# ─── CUTS SPEC FORMAT ────────────────────────────────────────────────────
#
# One clip per line:   <clip-number> <start> <end> [reverse]
#   clip-number   DJI sequence number (0649, or 649)
#   start / end   seconds, or 'end' for the end of the source
#   reverse       optional; also emit a reversed copy of this cut
# Blank lines and lines starting with # are ignored.
#
#   # 2026-07-18 shoot
#   0649 45 end reverse     # the main one
#   0657 0  end
#   0660 5  15
#   0660 19 end
#
# ─── OPTIONS ─────────────────────────────────────────────────────────────
#   --project <folder>   Project dir (default: current directory)
#   --cuts <file>        Cuts spec (default: <project>/CLIPS.txt)
#   --no-combine         Only cut clips, don't build the montages
#   --combine-only       Skip cutting, just rebuild montages from VIDEO/CLIPS/
#   --resolution <WxH>   Montage resolution (default: 1920x1080)
#   --crf <n>            Quality of the 4K cuts, lower = better (default: 20)
#   --help
#
# ─── NOTES ───────────────────────────────────────────────────────────────
# Cuts are re-encoded (HEVC, 4K) for frame-accurate in/out points — a stream
# copy would snap to the nearest keyframe and miss your marks. The montage is
# 1080p H.264 for a manageable file. Reversing buffers the whole cut in RAM
# (~12MB per 4K frame), which is why reverses run on the trimmed piece rather
# than the whole source. Needs ffmpeg: brew install ffmpeg.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/drone-config.sh"

PROJECT_DIR="$PWD"
CUTS_FILE=""
DO_CUT=true
DO_COMBINE=true
RESOLUTION="1920x1080"
CRF=20

while [[ $# -gt 0 ]]; do
    case $1 in
        --project) PROJECT_DIR="$2"; shift 2 ;;
        --cuts) CUTS_FILE="$2"; shift 2 ;;
        --no-combine) DO_COMBINE=false; shift ;;
        --combine-only) DO_CUT=false; shift ;;
        --resolution) RESOLUTION="$2"; shift 2 ;;
        --crf) CRF="$2"; shift 2 ;;
        --help|-h)
            sed -n '3,60p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

RES_W="${RESOLUTION%x*}"
RES_H="${RESOLUTION#*x}"
FPS=30

if ! command -v ffmpeg &>/dev/null || ! command -v ffprobe &>/dev/null; then
    echo -e "${RED}Error: ffmpeg is not installed (brew install ffmpeg)${NC}"; exit 1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || { echo -e "${RED}Project not found${NC}"; exit 1; }
RAW_DIR="$PROJECT_DIR/VIDEO/RAW"
CLIPS_DIR="$PROJECT_DIR/VIDEO/CLIPS"
OUTPUT_DIR="$PROJECT_DIR/OUTPUT"
PHOTO_DIR="$PROJECT_DIR/PHOTOS/INSTAGRAM"
[ -z "$CUTS_FILE" ] && CUTS_FILE="$PROJECT_DIR/CLIPS.txt"

if [ ! -d "$RAW_DIR" ]; then
    echo -e "${RED}Error: no VIDEO/RAW in $PROJECT_DIR${NC}"; exit 1
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}            Drone Clip Cutter & Combiner                        ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "Project: ${YELLOW}$PROJECT_DIR${NC}"
echo -e "Cuts:    ${YELLOW}$CUTS_FILE${NC}"
echo ""

# Resolve a DJI clip number to its RAW file
find_raw() {
    local num; num=$(printf "%04d" "$((10#$1))")
    find "$RAW_DIR" -maxdepth 1 -type f \
        \( -iname "*${num}*.mp4" -o -iname "*${num}*.mov" \) 2>/dev/null | head -1
}

dur_of() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null; }

# ─── Cut clips ─────────────────────────────────────────────────────────────
CUT_CLIPS=()   # forward cuts in spec order
declare -a CUT_HASREV

if [ "$DO_CUT" = true ]; then
    if [ ! -f "$CUTS_FILE" ]; then
        echo -e "${RED}Error: cuts spec not found: $CUTS_FILE${NC}"
        echo "Create it (see --help) or pass --combine-only."
        exit 1
    fi
    mkdir -p "$CLIPS_DIR"
    echo -e "${BLUE}Cutting clips → $CLIPS_DIR${NC}"
    echo "────────────────────────────────────────────────────────────────"

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"                       # strip trailing comments
        line="$(echo "$line" | xargs)"           # trim whitespace
        [ -z "$line" ] && continue
        read -r NUM START END FLAG <<< "$line"

        SRC=$(find_raw "$NUM")
        if [ -z "$SRC" ]; then
            echo -e "  ${RED}✗ clip $NUM not found in RAW${NC}"; continue
        fi
        SRCDUR=$(dur_of "$SRC")

        # Resolve start/end and build a readable label
        [ "$START" = "end" ] && START=0
        if [ "$END" = "end" ]; then
            END_LABEL="end"; TO_ARGS=()
        else
            END_LABEL="${END}s"; TO_ARGS=(-to "$END")
        fi
        LABEL="${NUM}_${START}s-${END_LABEL}"
        OUT="$CLIPS_DIR/${LABEL}.mp4"

        printf "  %-22s " "$LABEL"
        ffmpeg -nostdin -y -i "$SRC" -ss "$START" "${TO_ARGS[@]}" \
            -an -c:v libx265 -crf "$CRF" -preset medium -tag:v hvc1 \
            "$OUT" 2>/dev/null
        if [ -s "$OUT" ]; then
            echo -e "${GREEN}✓${NC} $(printf '%.1f' "$(dur_of "$OUT")")s"
            CUT_CLIPS+=("$OUT")
        else
            echo -e "${RED}✗ cut failed${NC}"; rm -f "$OUT"; continue
        fi

        # Reversed copy
        if [ "$FLAG" = "reverse" ]; then
            ROUT="$CLIPS_DIR/${LABEL}_reverse.mp4"
            printf "  %-22s " "${LABEL}_reverse"
            ffmpeg -nostdin -y -i "$OUT" -vf reverse \
                -an -c:v libx265 -crf "$CRF" -preset medium -tag:v hvc1 \
                "$ROUT" 2>/dev/null
            if [ -s "$ROUT" ]; then
                echo -e "${GREEN}✓${NC} $(printf '%.1f' "$(dur_of "$ROUT")")s"
                CUT_HASREV[${#CUT_CLIPS[@]}-1]="$ROUT"
            else
                echo -e "${RED}✗ reverse failed${NC}"; rm -f "$ROUT"
            fi
        fi
    done < "$CUTS_FILE"
    echo ""
else
    # Combine-only: pick up existing forward cuts (skip *_reverse)
    shopt -s nullglob
    for f in "$CLIPS_DIR"/*.mp4; do
        [[ "$f" == *_reverse.mp4 ]] && continue
        CUT_CLIPS+=("$f")
        [ -f "${f%.mp4}_reverse.mp4" ] && CUT_HASREV[${#CUT_CLIPS[@]}-1]="${f%.mp4}_reverse.mp4"
    done
fi

if [ ${#CUT_CLIPS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No clips to work with.${NC}"; exit 0
fi

[ "$DO_COMBINE" = false ] && { echo -e "${GREEN}Done (cuts only).${NC}"; exit 0; }

# ─── Build montages ────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dronecut.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

# Normalise any clip to 1080p / 30fps / yuv420p so segments concat cleanly
norm_video() {
    local in="$1" out="$2" extra="$3"
    ffmpeg -nostdin -y -i "$in" -vf \
"scale=${RES_W}:${RES_H}:force_original_aspect_ratio=decrease,pad=${RES_W}:${RES_H}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=${FPS}${extra:+,$extra}" \
        -an -c:v libx264 -preset fast -crf 21 -pix_fmt yuv420p "$out" 2>/dev/null
}

echo -e "${BLUE}Normalising segments for the montage...${NC}"
SEGS_CLIPS=()          # forward-only order
SEGS_WITHREV=()        # forward + inline reverse
i=0
for clip in "${CUT_CLIPS[@]}"; do
    seg="$TEMP_DIR/seg_${i}.mp4"
    printf "  %-26s " "$(basename "$clip")"
    norm_video "$clip" "$seg"
    if [ -s "$seg" ]; then echo -e "${GREEN}✓${NC}"; else echo -e "${RED}✗${NC}"; ((i++)); continue; fi
    SEGS_CLIPS+=("$seg")
    SEGS_WITHREV+=("$seg")
    if [ -n "${CUT_HASREV[$i]:-}" ]; then
        rseg="$TEMP_DIR/seg_${i}_rev.mp4"
        printf "  %-26s " "$(basename "${CUT_HASREV[$i]}")"
        norm_video "${CUT_HASREV[$i]}" "$rseg"
        if [ -s "$rseg" ]; then echo -e "${GREEN}✓${NC}"; SEGS_WITHREV+=("$rseg"); else echo -e "${RED}✗${NC}"; fi
    fi
    ((i++))
done
echo ""

concat_segs() {
    local out="$1"; shift
    local list="$TEMP_DIR/concat_$$_${RANDOM}.txt"; : > "$list"
    for s in "$@"; do echo "file '$s'" >> "$list"; done
    ffmpeg -nostdin -y -f concat -safe 0 -i "$list" -c copy "$out" 2>/dev/null \
        || ffmpeg -nostdin -y -f concat -safe 0 -i "$list" -c:v libx264 -preset fast -crf 21 -pix_fmt yuv420p "$out" 2>/dev/null
    rm -f "$list"
}

# 1. All cut clips, reverses inline where present
COMBINED_CLIPS="$OUTPUT_DIR/combined_clips.mp4"
echo -e "${BLUE}Building combined_clips.mp4 (${#SEGS_WITHREV[@]} segments)...${NC}"
concat_segs "$COMBINED_CLIPS" "${SEGS_WITHREV[@]}"
[ -s "$COMBINED_CLIPS" ] && echo -e "  ${GREEN}✓ $(printf '%.1f' "$(dur_of "$COMBINED_CLIPS")")s, $(du -h "$COMBINED_CLIPS" | cut -f1)${NC}" || echo -e "  ${RED}✗ failed${NC}"

# 2. Same, then Ken Burns photos
PHOTO_SEGS=()
if [ -d "$PHOTO_DIR" ]; then
    shopt -s nullglob
    PHOTOS=("$PHOTO_DIR"/*.jpg "$PHOTO_DIR"/*.JPG "$PHOTO_DIR"/*.jpeg "$PHOTO_DIR"/*.png "$PHOTO_DIR"/*.PNG)
    if [ ${#PHOTOS[@]} -gt 0 ]; then
        echo ""
        echo -e "${BLUE}Adding ${#PHOTOS[@]} photos (Ken Burns)...${NC}"
        PDUR=4; p=0
        for photo in "${PHOTOS[@]}"; do
            pseg="$TEMP_DIR/photo_${p}.mp4"
            case $((p % 4)) in
              0) zf="zoompan=z='min(zoom+0.0015,1.3)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=$((PDUR*FPS)):s=${RESOLUTION}:fps=$FPS" ;;
              1) zf="zoompan=z='if(lte(zoom,1.0),1.3,max(1.001,zoom-0.0015))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=$((PDUR*FPS)):s=${RESOLUTION}:fps=$FPS" ;;
              2) zf="zoompan=z='1.2':x='if(lte(on,1),0,min(iw/zoom-iw,x+2))':y='ih/2-(ih/zoom/2)':d=$((PDUR*FPS)):s=${RESOLUTION}:fps=$FPS" ;;
              3) zf="zoompan=z='1.2':x='if(lte(on,1),iw/zoom-iw,max(0,x-2))':y='ih/2-(ih/zoom/2)':d=$((PDUR*FPS)):s=${RESOLUTION}:fps=$FPS" ;;
            esac
            printf "  %-26s " "$(basename "$photo")"
            ffmpeg -nostdin -y -loop 1 -i "$photo" -vf "$zf,format=yuv420p" -t $PDUR \
                -c:v libx264 -preset fast -crf 21 "$pseg" 2>/dev/null
            if [ -s "$pseg" ]; then echo -e "${GREEN}✓${NC}"; PHOTO_SEGS+=("$pseg"); else echo -e "${RED}✗${NC}"; fi
            ((p++))
        done
    fi
fi

if [ ${#PHOTO_SEGS[@]} -gt 0 ]; then
    COMBINED_PHOTOS="$OUTPUT_DIR/combined_clips_photos.mp4"
    echo ""
    echo -e "${BLUE}Building combined_clips_photos.mp4...${NC}"
    concat_segs "$COMBINED_PHOTOS" "${SEGS_WITHREV[@]}" "${PHOTO_SEGS[@]}"
    [ -s "$COMBINED_PHOTOS" ] && echo -e "  ${GREEN}✓ $(printf '%.1f' "$(dur_of "$COMBINED_PHOTOS")")s, $(du -h "$COMBINED_PHOTOS" | cut -f1)${NC}" || echo -e "  ${RED}✗ failed${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Done.${NC}"
echo -e "  Cut clips: ${YELLOW}$CLIPS_DIR${NC}"
echo -e "  Montages:  ${YELLOW}$OUTPUT_DIR${NC}"
echo ""
