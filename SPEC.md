# Drone Footage Management System - Specification

## Executive Summary

A comprehensive workflow automation system for managing DJI drone footage, featuring intelligent file organization, hybrid storage strategy (local + cloud), and lifecycle management with automatic video/photo separation and optional compression.

## System Requirements

### Hardware
- **Mac**: macOS 10.15+ (tested on Darwin 24.0.0)
- **External Drive**: Minimum 500GB recommended (currently using "astroball" with 239GB capacity)
- **SD Card Reader**: USB 3.0+ recommended for faster transfers
- **Internet**: 50+ Mbps upload recommended for cloud archiving

### Software Dependencies
- **Required**:
  - Bash 4.0+
  - macOS built-in tools (diskutil, md5, bc)
- **Optional**:
  - FFmpeg (for video compression)
  - Dropbox client (for sync status)
  - DaVinci Resolve (for video editing)

## Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  DJI Drone  │────▶│   SD Card    │────▶│   Import    │
│             │     │ (/Volumes/DJI)│     │   Script    │
└─────────────┘     └──────────────┘     └─────────────┘
                                                 │
                                                 ▼
                                    ┌─────────────────────┐
                                    │   External Drive    │
                                    │  /Volumes/astroball │
                                    └─────────────────────┘
                                         │         │
                                         ▼         ▼
                                 ┌──────────┐ ┌──────────┐
                                 │  Active  │ │ Recently │
                                 │ Projects │ │Completed │
                                 └──────────┘ └──────────┘
                                       │           │
                                       │      (90 days)
                                       ▼           ▼
                                 ┌──────────┐ ┌──────────┐
                                 │ DaVinci  │ │ Archive  │
                                 │ Resolve  │ │  Script  │
                                 └──────────┘ └──────────┘
                                       │           │
                                       ▼           ▼
                                 ┌──────────────────────┐
                                 │      Dropbox         │
                                 │  ~/Dropbox/DroneFootage│
                                 └──────────────────────┘
```

## Core Components

### 1. Import System (`drone-import.sh`)

**Purpose**: Intelligently import and organize footage from SD card

**Features**:
- Auto-detection of DJI SD card at `/Volumes/DJI/DCIM`
- File type recognition and routing:
  - `.MP4/.MOV` → `VIDEO/RAW/`
  - `.JPG/.JPEG/.DNG` → `PHOTOS/RAW/`
  - `.SRT` → `VIDEO/SRT/`
  - Panorama sequences → `PHOTOS/PANORAMA/`
- MD5 checksum generation for data integrity
- Project metadata creation
- Safe SD card ejection

**Usage**:
```bash
./scripts/drone-import.sh "ProjectName" [SD_PATH]
```

**Process Flow**:
1. Validate external drive presence
2. Check SD card mount status
3. Analyze content (count files, calculate sizes)
4. Create project directory structure
5. Copy files with type-based organization
6. Generate checksums
7. Create metadata and README template
8. Optional SD card ejection

### 2. Archive System (`drone-archive.sh`)

**Purpose**: Manage project lifecycle and cloud backups

**Features**:
- Three archive strategies:
  - Finals only (default)
  - Compressed archive (`--compress`)
  - Full RAW preservation (`--keep-raw`)
- HEVC video compression (50% size reduction)
- Selective photo archiving
- 90-day retention scheduling
- Dropbox integration

**Usage**:
```bash
./scripts/drone-archive.sh "ProjectPath" [options]
Options:
  --compress     # HEVC compression
  --photos-only  # Archive selected photos only
  --keep-raw     # Upload RAW to Dropbox
```

**Process Flow**:
1. Analyze project contents
2. Create Dropbox directory structure
3. Copy finals to cloud
4. Optionally compress videos
5. Move to RecentlyCompleted
6. Schedule 90-day review
7. Generate archive summary

### 3. Monitoring System (`drone-summary.sh`)

**Purpose**: Provide project oversight and storage analytics

**Features**:
- Overall system status
- Individual project details
- Storage usage tracking
- Upcoming review reminders
- Dropbox sync status

**Usage**:
```bash
./scripts/drone-summary.sh [project-name]
```

**Output Includes**:
- Drive capacity and usage
- Active project listing
- Recently completed projects
- 90-day review schedule
- Cloud backup status

## Directory Structure

### External Drive Layout
```
/Volumes/astroball/DroneProjects/
├── ActiveProjects/              # Current work
│   └── YYYY-MM-DD_ProjectName/
│       ├── VIDEO/
│       │   ├── RAW/            # Original .MP4 files
│       │   ├── SRT/            # Telemetry data
│       │   └── EXPORTS/        # Rendered outputs
│       ├── PHOTOS/
│       │   ├── RAW/            # Original images
│       │   ├── PANORAMA/       # Panorama sequences
│       │   └── EDITED/         # Processed photos
│       ├── DaVinci/            # Project files
│       ├── METADATA/           # Checksums, logs
│       └── README.txt          # Shoot notes
├── RecentlyCompleted/          # 90-day retention
├── Archive/                    # Long-term storage
├── DaVinci_CacheFiles/         # Shared cache
├── Templates/                  # Reusable assets
│   ├── Intros/
│   ├── Outros/
│   ├── Music/
│   └── LUTs/
└── cleanup_schedule.txt       # Review tracking
```

### Dropbox Layout
```
~/Dropbox/DroneFootage/
├── YYYY/
│   ├── MM-MonthName/
│   │   └── YYYY-MM-DD_ProjectName/
│   │       ├── VIDEO_FINALS/
│   │       ├── PHOTO_SELECTS/
│   │       ├── RAW_ARCHIVE/     # Optional
│   │       ├── METADATA/
│   │       └── archive_summary.txt
└── Archive/
```

## Data Flow & Lifecycle

### Phase 1: Capture (Day 0)
```
SD Card → Import Script → External Drive (ActiveProjects)
```
- Full quality preservation
- Automatic organization
- Checksum verification

### Phase 2: Production (Days 1-30)
```
ActiveProjects → DaVinci Resolve → Exports
```
- Direct editing from external drive
- Multiple export versions
- Photo selection/editing

### Phase 3: Completion (Day 30+)
```
ActiveProjects → Archive Script → RecentlyCompleted + Dropbox
```
- Finals uploaded to cloud
- Project moved to retention
- 90-day countdown begins

### Phase 4: Review (Day 90)
```
RecentlyCompleted → Decision Point → Archive/Delete
```
- Keep RAW: Upload to Dropbox (online-only)
- Delete RAW: Remove, keep finals only

## File Naming Conventions

### Projects
Format: `YYYY-MM-DD_DescriptiveName`
- Example: `2025-11-10_Coastline_Sunset`

### Files
- **Original**: Preserve DJI naming (`DJI_YYYYMMDDHHMMSS_####_D.ext`)
- **Exports**: `ProjectName_v#_Resolution.mp4`
  - Example: `Coastline_v1_4K.mp4`

### Folders
- Use UPPERCASE for system folders (VIDEO, PHOTOS)
- Use CamelCase for project names
- Use lowercase for metadata files

## Performance Metrics

### Transfer Speeds
- **USB 3.0 SD Reader**: ~100-150 MB/s
- **30GB import**: 3-5 minutes
- **Checksum generation**: 2-3 minutes
- **Total import time**: 7-11 minutes

### Compression Ratios
- **HEVC (H.265)**: 40-60% size reduction
- **Quality settings**: CRF 23 (visually lossless)
- **Processing speed**: ~2-5x realtime on M1/M2

### Storage Projections
- **Per shoot**: 30-100GB RAW
- **After compression**: 15-50GB
- **Finals only**: 2-5GB
- **Monthly (4 shoots)**: 120-400GB RAW, 8-20GB finals

## Security & Integrity

### Data Protection
1. **MD5 Checksums**: Generated for all media files
2. **Verification**: Pre/post transfer comparison
3. **Logging**: Complete audit trail
4. **No Auto-delete**: Manual SD card formatting only

### Backup Strategy
- **3-2-1 Rule Implementation**:
  - 3 copies: SD, External, Cloud
  - 2 media types: SSD + Cloud storage
  - 1 offsite: Dropbox

## Usage Guide

### Basic Workflow

#### 1. Import New Footage
```bash
# Navigate to project directory
cd ~/Documents/workspace/projects/wheeldogg_channel

# Import from SD card
./scripts/drone-import.sh "Beach_Sunset"

# Output shows:
# - File counts by type
# - Total size
# - Progress indicators
# - Final location
```

#### 2. Edit in DaVinci Resolve
```bash
# Project location
/Volumes/astroball/DroneProjects/ActiveProjects/2025-11-10_Beach_Sunset/

# Import media from: VIDEO/RAW/
# Export to: VIDEO/EXPORTS/
# Cache files: DaVinci/
```

#### 3. Archive Completed Project
```bash
# Basic archive (finals only)
./scripts/drone-archive.sh "2025-11-10_Beach_Sunset"

# With compression
./scripts/drone-archive.sh "2025-11-10_Beach_Sunset" --compress

# Keep everything
./scripts/drone-archive.sh "2025-11-10_Beach_Sunset" --keep-raw
```

#### 4. Monitor Projects
```bash
# Overall summary
./scripts/drone-summary.sh

# Specific project
./scripts/drone-summary.sh "Beach_Sunset"
```

### Advanced Operations

#### Batch Import
```bash
# Multiple cards same project
for card in DJI DJI_2; do
    ./scripts/drone-import.sh "BigProject_$card" "/Volumes/$card/DCIM"
done
```

#### Automated Compression
```bash
# Compress all completed projects
for project in /Volumes/astroball/DroneProjects/RecentlyCompleted/*; do
    ./scripts/drone-archive.sh "$project" --compress
done
```

#### Cleanup Old Projects
```bash
# Find projects older than 90 days
find /Volumes/astroball/DroneProjects/RecentlyCompleted \
    -maxdepth 1 -type d -mtime +90 -exec basename {} \;
```

## Suggested Improvements

### 1. Automation Enhancements

#### Auto-Import on SD Card Detection
```bash
# LaunchAgent for automatic import
# ~/Library/LaunchAgents/com.drone.autoimport.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.drone.autoimport</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/drone-import.sh</string>
        <string>Auto_Import</string>
    </array>
    <key>StartOnMount</key>
    <array>
        <string>/Volumes/DJI</string>
    </array>
</dict>
</plist>
```

#### Background Compression
```bash
# Add to drone-archive.sh
if [ "$COMPRESS_VIDEO" = true ]; then
    nohup compress_videos.sh "$PROJECT_PATH" &
    echo "Compression running in background (PID: $!)"
fi
```

### 2. Metadata Enhancement

#### GPS Extraction & Mapping
```bash
# Extract GPS from SRT to KML
extract_gps() {
    python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    coords = re.findall(r'GPS\(([\d.-]+),([\d.-]+),([\d.-]+)\)', f.read())
    # Generate KML...
" "$1"
}
```

#### Thumbnail Generation
```bash
# Add to import script
generate_thumbnails() {
    for video in "$1"/*.mp4; do
        ffmpeg -i "$video" -vf "select='not(mod(n,300))',scale=320:180,tile=4x3" \
            -frames:v 1 "${video%.mp4}_thumb.jpg"
    done
}
```

### 3. Cloud Integration

#### Direct Cloud Upload
```bash
# Add Dropbox CLI integration
upload_to_cloud() {
    dbxcli put "$1" "/DroneFootage/$2" &
    echo "Uploading to Dropbox in background"
}
```

#### Multi-Cloud Backup
```bash
# Add support for multiple services
CLOUD_SERVICES=("dropbox" "gdrive" "aws")
for service in "${CLOUD_SERVICES[@]}"; do
    upload_to_$service "$PROJECT_PATH"
done
```

### 4. AI/ML Features

#### Shot Detection & Categorization
```python
# Auto-tag footage types
def categorize_shot(video_path):
    # Use ML model to detect:
    # - Establishing shots
    # - Close-ups
    # - Tracking shots
    # - Panoramas
    return shot_type
```

#### Quality Assessment
```python
# Auto-rate footage quality
def assess_quality(video_path):
    # Check for:
    # - Sharpness
    # - Exposure
    # - Stability
    # - Composition
    return quality_score
```

### 5. Workflow Optimizations

#### Proxy Generation
```bash
# Auto-generate editing proxies
create_proxies() {
    mkdir -p "$1/VIDEO/PROXIES"
    for video in "$1/VIDEO/RAW"/*.mp4; do
        ffmpeg -i "$video" -vf scale=1920:1080 -c:v h264 \
            -preset ultrafast "$1/VIDEO/PROXIES/$(basename "$video")"
    done
}
```

#### Smart Archiving
```bash
# AI-driven archive decisions
suggest_archive_action() {
    # Based on:
    # - File access patterns
    # - Project type
    # - Available storage
    # - Historical preferences
    echo "Recommendation: compress and archive"
}
```

### 6. User Experience

#### Interactive CLI
```bash
# Add interactive mode
if [ "$1" = "--interactive" ]; then
    echo "Select action:"
    echo "1) Import footage"
    echo "2) Archive project"
    echo "3) View summary"
    read -p "Choice: " choice
    # Handle selection...
fi
```

#### Web Dashboard
```python
# Flask-based monitoring dashboard
from flask import Flask, render_template
app = Flask(__name__)

@app.route('/')
def dashboard():
    projects = get_project_stats()
    return render_template('dashboard.html', projects=projects)
```

### 7. Performance Improvements

#### Parallel Processing
```bash
# Use GNU parallel for faster imports
find "$SD_PATH" -type f -name "*.mp4" | \
    parallel -j4 cp {} "$PROJECT_DIR/VIDEO/RAW/"
```

#### Incremental Backups
```bash
# Only sync changed files
rsync -av --ignore-existing \
    "$PROJECT_PATH/" \
    "$DROPBOX_PATH/"
```

### 8. Integration Features

#### DaVinci Resolve API
```python
# Auto-create Resolve projects
import DaVinciResolveScript as dvr
resolve = dvr.scriptapp("Resolve")
project = resolve.GetProjectManager().CreateProject(name)
```

#### Mobile Companion App
- Remote monitoring
- Shoot logging
- Quick preview
- Cloud sync status

## Error Handling

### Common Issues & Solutions

#### SD Card Not Detected
```bash
# Diagnostic steps
ls /Volumes/ | grep -i dji
diskutil list
# Manual mount
diskutil mount /dev/disk2s1
```

#### Insufficient Storage
```bash
# Check before import
REQUIRED=$(du -s "$SD_PATH" | cut -f1)
AVAILABLE=$(df "$EXTERNAL_DRIVE" | tail -1 | awk '{print $4}')
if [ $REQUIRED -gt $AVAILABLE ]; then
    echo "Insufficient space"
    exit 1
fi
```

#### Compression Failure
```bash
# Fallback to original
if ! ffmpeg -i "$input" -c:v libx265 "$output"; then
    echo "Compression failed, keeping original"
    cp "$input" "$output"
fi
```

## Testing & Validation

### Unit Tests
```bash
# Test file organization
test_import() {
    create_test_files
    ./drone-import.sh "Test"
    verify_structure
    cleanup_test
}
```

### Integration Tests
```bash
# Full workflow test
test_workflow() {
    import_test_footage
    archive_test_project
    verify_dropbox_sync
    cleanup_all
}
```

## Maintenance

### Log Rotation
```bash
# Add to cron
0 0 1 * * find /Volumes/astroball/DroneProjects -name "*.log" \
    -mtime +30 -exec gzip {} \;
```

### Storage Cleanup
```bash
# Monthly cleanup script
cleanup_old_projects() {
    # Remove empty directories
    find "$DRONE_BASE" -type d -empty -delete
    # Compress old logs
    find "$DRONE_BASE" -name "*.log" -mtime +30 -exec gzip {} \;
    # Remove old checksums
    find "$DRONE_BASE" -name "*.md5" -mtime +180 -delete
}
```

## License & Support

### License
MIT License - Free to use and modify

### Support Channels
- Documentation: `DRONE_WORKFLOW_GUIDE.md`
- Quick Start: `QUICK_START.txt`
- Issues: Create issue in project repository

### Contributing
Improvements welcome via pull requests

## Version History

### v1.0.0 (2025-11-11)
- Initial release
- Core import/archive/summary functionality
- Video/photo separation
- 90-day retention system
- Dropbox integration
- HEVC compression support

### Planned Features (v2.0)
- Auto-import on SD detection
- Web dashboard
- Mobile app integration
- ML-based shot categorization
- Multi-cloud support
- Proxy generation
- GPS visualization

---

*Specification for Drone Footage Management System - Designed for efficiency, reliability, and scalability*