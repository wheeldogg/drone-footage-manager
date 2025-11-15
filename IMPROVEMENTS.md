# Drone Workflow - Suggested Improvements

## Priority 1: Immediate Quality-of-Life Enhancements

### 1. Auto-Detection & Smart Prompts
**Problem**: Need to manually specify project names and remember commands
**Solution**: Add intelligent detection and suggestions

```bash
# Add to drone-import.sh
suggest_project_name() {
    # Detect date from first file
    FIRST_FILE=$(ls /Volumes/DJI/DCIM/*.MP4 2>/dev/null | head -1)
    if [ -f "$FIRST_FILE" ]; then
        # Extract date from DJI filename
        FILE_DATE=$(basename "$FIRST_FILE" | cut -d'_' -f2 | cut -c1-8)
        FORMATTED_DATE=$(date -j -f "%Y%m%d" "$FILE_DATE" +"%Y-%m-%d" 2>/dev/null)

        # Suggest name based on time of day
        HOUR=$(echo "$FILE_DATE" | cut -c9-10)
        if [ "$HOUR" -lt 08 ]; then
            TIME_PERIOD="Sunrise"
        elif [ "$HOUR" -lt 12 ]; then
            TIME_PERIOD="Morning"
        elif [ "$HOUR" -lt 17 ]; then
            TIME_PERIOD="Afternoon"
        elif [ "$HOUR" -lt 20 ]; then
            TIME_PERIOD="Evening"
        else
            TIME_PERIOD="Night"
        fi

        echo "Suggested name: ${FORMATTED_DATE}_${TIME_PERIOD}_Flight"
        echo "Press Enter to use, or type custom name:"
        read -r CUSTOM_NAME
        PROJECT_NAME="${CUSTOM_NAME:-${FORMATTED_DATE}_${TIME_PERIOD}_Flight}"
    fi
}
```

### 2. Quick Launch Aliases
**Problem**: Need to cd to directory and type full script paths
**Solution**: Add to `~/.zshrc` or `~/.bash_profile`

```bash
# Drone workflow aliases
alias drone-import='~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-import.sh'
alias drone-archive='~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-archive.sh'
alias drone-status='~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-summary.sh'
alias drone-cd='cd /Volumes/astroball/DroneProjects/ActiveProjects'

# Even quicker with auto-detection
drone() {
    case "$1" in
        import|i)
            shift
            drone-import "$@"
            ;;
        archive|a)
            shift
            drone-archive "$@"
            ;;
        status|s)
            shift
            drone-status "$@"
            ;;
        cd)
            drone-cd
            ;;
        *)
            echo "Usage: drone {import|archive|status|cd} [args]"
            ;;
    esac
}
```

### 3. Progress Notifications
**Problem**: Long operations run without feedback
**Solution**: Add macOS notifications

```bash
# Add to scripts
notify() {
    if command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "Drone Workflow" -message "$1" -sound default
    elif command -v osascript &> /dev/null; then
        osascript -e "display notification \"$1\" with title \"Drone Workflow\""
    fi
}

# Usage in scripts
notify "Import complete: $PROJECT_NAME"
notify "Archive uploaded to Dropbox"
notify "Compression finished (saved ${SAVED_SPACE}GB)"
```

## Priority 2: Automation & Speed

### 4. Parallel File Copying
**Problem**: Sequential copying is slow for many files
**Solution**: Use parallel processing

```bash
# Install GNU parallel
brew install parallel

# Update import script
copy_files_parallel() {
    echo "Copying files (using parallel processing)..."

    # Videos in parallel (usually fewer, larger files)
    find "$SD_PATH" -name "*.MP4" -o -name "*.MOV" | \
        parallel -j4 --bar cp {} "$PROJECT_DIR/VIDEO/RAW/"

    # Photos in parallel (many small files)
    find "$SD_PATH" -name "*.JPG" -o -name "*.JPEG" | \
        parallel -j8 --bar cp {} "$PROJECT_DIR/PHOTOS/RAW/"
}
```

### 5. Smart Compression Queue
**Problem**: Compression blocks the terminal
**Solution**: Background queue system

```bash
# Create compression-queue.sh
#!/bin/bash
QUEUE_DIR="/Volumes/astroball/DroneProjects/.compression_queue"
mkdir -p "$QUEUE_DIR"

add_to_queue() {
    echo "$1" >> "$QUEUE_DIR/pending.txt"
    if ! pgrep -f "process_compression_queue" > /dev/null; then
        nohup process_compression_queue &
    fi
}

process_compression_queue() {
    while true; do
        if [ -s "$QUEUE_DIR/pending.txt" ]; then
            VIDEO=$(head -1 "$QUEUE_DIR/pending.txt")
            sed -i '1d' "$QUEUE_DIR/pending.txt"

            compress_video "$VIDEO"
            notify "Compressed: $(basename "$VIDEO")"
        else
            sleep 10
        fi
    done
}
```

### 6. Auto-Import on SD Insert
**Problem**: Manual script execution required
**Solution**: Automated detection and import

```bash
# Create ~/Library/LaunchAgents/com.drone.autodetect.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.drone.autodetect</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/osascript</string>
        <string>-e</string>
        <string>
        tell application "Terminal"
            if not (exists window 1) then reopen
            activate
            do script "drone-import"
        end tell
        </string>
    </array>
    <key>StartOnMount</key>
    <dict>
        <key>PathsToWatch</key>
        <array>
            <string>/Volumes</string>
        </array>
    </dict>
</dict>
</plist>

# Enable with:
launchctl load ~/Library/LaunchAgents/com.drone.autodetect.plist
```

## Priority 3: Intelligence & Analysis

### 7. Flight Statistics Dashboard
**Problem**: No quick way to see flight patterns and statistics
**Solution**: Extract and visualize telemetry

```python
#!/usr/bin/env python3
# flight-stats.py
import re
import glob
import pandas as pd
import matplotlib.pyplot as plt

def analyze_srt_files(project_path):
    srt_files = glob.glob(f"{project_path}/VIDEO/SRT/*.SRT")

    stats = {
        'max_altitude': 0,
        'max_speed': 0,
        'total_distance': 0,
        'flight_time': 0,
        'battery_used': 0
    }

    for srt in srt_files:
        with open(srt) as f:
            content = f.read()
            # Extract telemetry
            altitudes = re.findall(r'altitude: ([\d.]+)', content)
            speeds = re.findall(r'speed: ([\d.]+)', content)

            if altitudes:
                stats['max_altitude'] = max(float(a) for a in altitudes)
            if speeds:
                stats['max_speed'] = max(float(s) for s in speeds)

    return stats

# Generate report
def generate_flight_report(project_name):
    stats = analyze_srt_files(f"/Volumes/astroball/DroneProjects/ActiveProjects/{project_name}")

    print(f"""
    Flight Statistics for {project_name}
    =====================================
    Max Altitude: {stats['max_altitude']}m
    Max Speed: {stats['max_speed']}km/h
    Flight Time: {stats['flight_time']}min
    Coverage Area: ~{stats['total_distance']}km
    """)
```

### 8. Duplicate Detection
**Problem**: May import same footage multiple times
**Solution**: Check for duplicates before import

```bash
# Add to import script
check_duplicates() {
    echo "Checking for duplicate files..."

    for file in "$SD_PATH"/*.MP4; do
        filename=$(basename "$file")
        if find "$DRONE_BASE" -name "$filename" 2>/dev/null | grep -q .; then
            echo "  ⚠️  Duplicate found: $filename"
            echo "  Location: $(find "$DRONE_BASE" -name "$filename")"
            DUPLICATES_FOUND=true
        fi
    done

    if [ "$DUPLICATES_FOUND" = true ]; then
        read -p "Duplicates found. Continue anyway? (y/n): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
}
```

### 9. Smart Storage Management
**Problem**: No warning when running low on space
**Solution**: Predictive storage monitoring

```bash
# Add to summary script
storage_forecast() {
    # Calculate average project size
    AVG_SIZE=$(find "$ACTIVE_DIR" -maxdepth 1 -type d -exec du -s {} \; | \
        awk '{sum+=$1; count++} END {print int(sum/count/1024/1024)}')

    # Get available space
    AVAILABLE_GB=$(($(df /Volumes/astroball | tail -1 | awk '{print $4}') / 1024 / 1024))

    # Calculate capacity
    PROJECTS_REMAINING=$((AVAILABLE_GB / AVG_SIZE))

    echo "Storage Forecast:"
    echo "  Average project: ${AVG_SIZE}GB"
    echo "  Available space: ${AVAILABLE_GB}GB"
    echo "  Capacity: ~${PROJECTS_REMAINING} more projects"

    if [ $PROJECTS_REMAINING -lt 3 ]; then
        echo "  ⚠️  WARNING: Archive old projects soon!"
    fi
}
```

## Priority 4: Enhanced Safety & Recovery

### 10. Incremental Backups
**Problem**: Re-copying everything wastes time
**Solution**: Only copy new/changed files

```bash
# Update import to support incremental
incremental_import() {
    if [ -d "$PROJECT_DIR" ]; then
        echo "Project exists. Performing incremental import..."
        rsync -av --ignore-existing --progress \
            "$SD_PATH/" "$PROJECT_DIR/RAW_IMPORT/"
    else
        standard_import
    fi
}
```

### 11. Verification & Recovery
**Problem**: No easy way to verify or recover from corruption
**Solution**: Enhanced verification system

```bash
# verify-integrity.sh
#!/bin/bash
verify_project() {
    PROJECT="$1"
    echo "Verifying integrity of $PROJECT..."

    cd "$PROJECT/METADATA"
    if [ -f checksums.md5 ]; then
        FAILURES=0
        while IFS= read -r line; do
            md5sum -c <<< "$line" 2>/dev/null || ((FAILURES++))
        done < checksums.md5

        if [ $FAILURES -eq 0 ]; then
            echo "✓ All files verified successfully"
        else
            echo "⚠️  $FAILURES files failed verification"
            echo "Run recovery tool? (y/n)"
        fi
    fi
}
```

### 12. Emergency SD Card Recovery
**Problem**: Accidental deletion before import
**Solution**: Direct SD backup option

```bash
# Add emergency backup mode
emergency_backup() {
    echo "EMERGENCY BACKUP MODE"
    echo "Creating direct SD card image..."

    BACKUP_NAME="SD_Backup_$(date +%Y%m%d_%H%M%S).dmg"

    # Create disk image
    sudo dd if=/dev/disk2 of="/Volumes/astroball/Emergency/$BACKUP_NAME" bs=1m

    echo "Backup saved to: $BACKUP_NAME"
    echo "Use Disk Utility to mount and recover files"
}
```

## Priority 5: Integration & Workflow

### 13. DaVinci Resolve Auto-Setup
**Problem**: Manual project creation in Resolve
**Solution**: Automated project setup

```python
# davinci-setup.py
import os
import DaVinciResolveScript as dvr

def create_drone_project(project_name, media_path):
    resolve = dvr.scriptapp("Resolve")
    pm = resolve.GetProjectManager()

    # Create project
    project = pm.CreateProject(project_name)

    # Set up bins
    mp = project.GetMediaPool()
    root = mp.GetRootFolder()

    # Create folder structure
    video_bin = mp.AddSubFolder(root, "VIDEO")
    photo_bin = mp.AddSubFolder(root, "PHOTOS")
    export_bin = mp.AddSubFolder(root, "EXPORTS")

    # Import media
    video_clips = mp.ImportMedia(f"{media_path}/VIDEO/RAW/*.MP4")
    mp.MoveClips(video_clips, video_bin)

    print(f"✓ DaVinci project created: {project_name}")
```

### 14. Quick Preview Generation
**Problem**: Need to open Resolve to preview footage
**Solution**: Generate preview sheets

```bash
# Add to import script
generate_preview() {
    echo "Generating preview sheets..."

    for video in "$PROJECT_DIR/VIDEO/RAW"/*.MP4; do
        filename=$(basename "$video" .MP4)

        # Create thumbnail grid
        ffmpeg -i "$video" -vf "select='not(mod(n,300))',scale=320:180,tile=5x4" \
            -frames:v 1 "$PROJECT_DIR/METADATA/${filename}_preview.jpg" 2>/dev/null
    done

    # Create HTML preview page
    cat > "$PROJECT_DIR/METADATA/preview.html" <<EOF
    <!DOCTYPE html>
    <html>
    <head><title>$PROJECT_NAME Preview</title></head>
    <body>
    <h1>$PROJECT_NAME</h1>
    EOF

    for preview in "$PROJECT_DIR/METADATA"/*_preview.jpg; do
        echo "<img src='$(basename "$preview")' style='max-width:100%'><br>" >> "$PROJECT_DIR/METADATA/preview.html"
    done

    echo "</body></html>" >> "$PROJECT_DIR/METADATA/preview.html"

    # Open in browser
    open "$PROJECT_DIR/METADATA/preview.html"
}
```

## Implementation Priority

### Week 1 - Quick Wins
1. ✅ Add aliases to shell profile
2. ✅ Install terminal-notifier for notifications
3. ✅ Add duplicate detection

### Week 2 - Automation
4. ⏳ Set up auto-import on SD detection
5. ⏳ Implement parallel copying
6. ⏳ Add progress bars

### Week 3 - Intelligence
7. 📋 Create flight statistics analyzer
8. 📋 Add storage forecasting
9. 📋 Generate preview sheets

### Month 2 - Advanced
10. 🔮 DaVinci Resolve integration
11. 🔮 Web dashboard
12. 🔮 Mobile app companion

## Quick Implementation Guide

### Step 1: Add Aliases (Do Now - 2 minutes)
```bash
echo '
# Drone workflow shortcuts
alias drone="~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-import.sh"
alias drone-import="~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-import.sh"
alias drone-archive="~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-archive.sh"
alias drone-status="~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-summary.sh"
' >> ~/.zshrc

source ~/.zshrc
```

### Step 2: Install Enhancements (5 minutes)
```bash
# Install helpful tools
brew install terminal-notifier  # Desktop notifications
brew install parallel           # Parallel processing
brew install pv                 # Progress bars
brew install watch              # Monitor commands
```

### Step 3: Create Quick Launcher (5 minutes)
```bash
# Create ~/bin/drone command
mkdir -p ~/bin
cat > ~/bin/drone <<'EOF'
#!/bin/bash
case "$1" in
    "")
        echo "What would you like to do?"
        echo "1) Import from SD card"
        echo "2) Archive project"
        echo "3) View status"
        read -p "Choice: " choice
        case $choice in
            1) ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-import.sh ;;
            2) ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-archive.sh ;;
            3) ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-summary.sh ;;
        esac
        ;;
    *)
        ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-$1.sh "${@:2}"
        ;;
esac
EOF
chmod +x ~/bin/drone
```

## Conclusion

These improvements focus on:
1. **Reducing friction** - Fewer commands to remember
2. **Saving time** - Parallel processing, smart defaults
3. **Preventing mistakes** - Duplicate detection, verification
4. **Better insights** - Statistics, previews, forecasting
5. **Future-proofing** - Modular design for easy enhancement

Start with Priority 1 improvements for immediate benefits, then gradually implement others based on your workflow needs.