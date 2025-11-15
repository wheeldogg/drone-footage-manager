# Drone Footage Management System - User Guide

## Overview
This system helps you efficiently manage drone footage with automatic organization, smart archiving, and compression options. It separates videos and photos, tracks projects through their lifecycle, and uses a hybrid storage approach (external drive + Dropbox).

## Quick Start

### 1. Import footage from SD card
```bash
cd ~/Documents/workspace/projects/wheeldogg_channel
./scripts/drone-import.sh "ProjectName"
```

### 2. Check project status
```bash
./scripts/drone-summary.sh
```

### 3. Archive completed projects
```bash
./scripts/drone-archive.sh "ProjectName"
```

## System Architecture

```
External Drive (astroball):
/Volumes/astroball/DroneProjects/
├── ActiveProjects/       # Currently editing
├── RecentlyCompleted/    # 90-day retention
├── Archive/              # Long-term storage
└── Templates/            # Reusable assets

Dropbox (Cloud Backup):
~/Dropbox/DroneFootage/
├── 2025/                 # Organized by year/month
│   ├── 11-November/
│   │   └── ProjectName/
│   │       ├── VIDEO_FINALS/
│   │       └── PHOTO_SELECTS/
└── Archive/              # Old projects
```

## Detailed Workflows

### Importing New Footage

1. **Connect your DJI SD card** to your Mac
2. **Run the import script**:
   ```bash
   ./scripts/drone-import.sh "Coastline_Shoot"
   ```
3. **What happens automatically**:
   - Videos (.MP4) → VIDEO/RAW/
   - Photos (.JPG) → PHOTOS/RAW/
   - Panoramas → PHOTOS/PANORAMA/
   - Telemetry (.SRT) → VIDEO/SRT/
   - Checksums generated for verification
   - README.txt created for shoot notes

### Editing in DaVinci Resolve

1. **Open DaVinci Resolve**
2. **Create new project** in: `/Volumes/astroball/DroneProjects/ActiveProjects/[YourProject]/DaVinci/`
3. **Import media** from: `VIDEO/RAW/` folder
4. **Export finals** to: `VIDEO/EXPORTS/`
5. **For best performance**:
   - Set cache location to project's DaVinci folder
   - Use proxy mode if 4K playback is choppy
   - Export multiple versions (4K master, 1080p web)

### Archiving Completed Projects

#### Option 1: Finals Only (Default)
```bash
./scripts/drone-archive.sh "2025-11-10_Coastline_Shoot"
```
- Uploads only exported videos to Dropbox
- Keeps RAW on external for 90 days
- Best for personal projects

#### Option 2: Compress & Archive
```bash
./scripts/drone-archive.sh "ProjectName" --compress
```
- Compresses videos with HEVC (50% size reduction)
- Maintains visual quality
- Good for long-term storage

#### Option 3: Full Archive with RAW
```bash
./scripts/drone-archive.sh "ProjectName" --keep-raw
```
- Uploads everything to Dropbox
- Set RAW folder to "online-only" after sync
- Best for client work

### 90-Day Review Process

Projects in `RecentlyCompleted/` are reviewed after 90 days:

1. **Check upcoming reviews**:
   ```bash
   ./scripts/drone-summary.sh
   ```

2. **For each project, decide**:
   - **Important?** → Upload RAW to Dropbox (online-only)
   - **Not needed?** → Delete RAW, keep finals only
   - **Unsure?** → Keep another 30 days

## Script Reference

### drone-import.sh
**Purpose**: Import footage from SD card with smart organization
```bash
Usage: ./scripts/drone-import.sh "ProjectName" [SD_PATH]

Examples:
./scripts/drone-import.sh "Beach_Sunset"
./scripts/drone-import.sh "Client_Property" "/Volumes/DJI/DCIM"
```

**Features**:
- Auto-detects DJI SD card
- Separates videos/photos/panoramas
- Generates checksums
- Creates project template
- Option to eject SD card

### drone-archive.sh
**Purpose**: Archive completed projects with flexible options
```bash
Usage: ./scripts/drone-archive.sh "ProjectPath" [options]

Options:
  --compress     Compress videos with HEVC
  --photos-only  Archive only selected photos
  --keep-raw     Upload RAW footage to Dropbox

Examples:
./scripts/drone-archive.sh "2025-11-10_Beach"
./scripts/drone-archive.sh "ClientWork" --keep-raw
./scripts/drone-archive.sh "TestFlight" --compress
```

### drone-summary.sh
**Purpose**: View project statistics and storage usage
```bash
Usage: ./scripts/drone-summary.sh [project-name]

Examples:
./scripts/drone-summary.sh                    # Overall summary
./scripts/drone-summary.sh "Beach_Sunset"     # Specific project
```

**Shows**:
- Active projects and sizes
- Recently completed with countdown
- Upcoming 90-day reviews
- Storage usage statistics
- Dropbox sync status

## File Organization

### Project Structure
```
2025-11-10_ProjectName/
├── VIDEO/
│   ├── RAW/           # Original drone footage
│   ├── SRT/           # GPS/telemetry data
│   └── EXPORTS/       # Your edited videos
├── PHOTOS/
│   ├── RAW/           # Original photos
│   ├── PANORAMA/      # Panorama sequences
│   └── EDITED/        # Processed photos
├── DaVinci/           # Resolve project files
├── METADATA/          # Checksums, logs
└── README.txt         # Shoot notes template
```

### Naming Convention
- Projects: `YYYY-MM-DD_DescriptiveName`
- Files: Keep DJI originals (`DJI_YYYYMMDDHHMMSS_####_D.MP4`)
- Exports: `ProjectName_v1_4K.mp4`, `ProjectName_v1_1080p.mp4`

## Storage Management

### Space Requirements
- **Active Project**: 30-100GB each
- **Recently Completed**: 100-300GB total (2-3 projects)
- **Dropbox (Finals only)**: 2-5GB per project
- **Dropbox (With RAW)**: 30-100GB per project

### Recommended Setup
- **External Drive**: 500GB minimum (1TB recommended)
- **Dropbox Plan**: Plus (2TB) if archiving RAW
- **Internet**: 50+ Mbps upload for RAW archiving

### Space-Saving Tips
1. **Use compression** for archived videos (50% reduction)
2. **Delete test footage** after 30 days
3. **Keep only best photos** (not all 200 shots)
4. **Set Dropbox to online-only** after upload
5. **Archive to external** drive for old projects

## Dropbox Integration

### Setting Files to Online-Only
After uploading large RAW folders:
1. Wait for sync to complete (check Dropbox icon)
2. Right-click the folder in Finder
3. Select "Make Available Online-only"
4. Files remain in cloud but don't use local space

### Selective Sync
To save MacBook space:
1. Dropbox Preferences → Sync → Selective Sync
2. Uncheck old project folders
3. They remain in cloud but not on laptop

## Troubleshooting

### SD Card Not Found
```bash
# Check mounted volumes
ls /Volumes/

# Look for DJI volumes
ls /Volumes/ | grep -i dji

# Specify custom path
./scripts/drone-import.sh "Project" "/Volumes/YOUR_SD_CARD/DCIM"
```

### External Drive Not Mounted
```bash
# Check if astroball is connected
ls /Volumes/astroball

# If different name, update scripts:
# Edit EXTERNAL_DRIVE="/Volumes/YourDriveName" in all scripts
```

### Dropbox Not Syncing
```bash
# Check status
dropbox status

# Force sync
dropbox start

# Check available space
df -h ~/Dropbox
```

### Video Compression Failed
```bash
# Check ffmpeg installation
ffmpeg -version

# Install if missing
brew install ffmpeg

# Try manual compression
ffmpeg -i input.mp4 -c:v libx265 -crf 23 -preset medium output.mp4
```

## Best Practices

### During Shoot
1. **Format SD card** in drone (not computer)
2. **Note location** and conditions
3. **Shoot in batches** (easier to organize)
4. **Keep spare SD cards** for backup

### After Import
1. **Verify files** before formatting SD card
2. **Edit README.txt** with shoot details
3. **Review footage** quickly to delete obvious mistakes
4. **Create project** in DaVinci immediately

### During Editing
1. **Work from external drive** (not Dropbox)
2. **Use proxies** for smooth 4K editing
3. **Export multiple versions** (4K, 1080p, social)
4. **Save DaVinci project** regularly

### After Completion
1. **Archive within 30 days** of finishing
2. **Upload finals immediately** to Dropbox
3. **Decide on RAW storage** (client vs personal)
4. **Set calendar reminder** for 90-day review

## Advanced Features

### Custom Compression Settings
Edit `drone-archive.sh` to adjust HEVC settings:
```bash
# Higher quality (larger files)
ffmpeg -i input.mp4 -c:v libx265 -crf 20 -preset slow output.mp4

# Faster compression (lower quality)
ffmpeg -i input.mp4 -c:v libx265 -crf 25 -preset fast output.mp4
```

### Batch Processing
Process multiple projects:
```bash
# Archive all projects older than 30 days
for project in /Volumes/astroball/DroneProjects/ActiveProjects/*; do
    if [ $(find "$project" -maxdepth 0 -mtime +30 | wc -l) -gt 0 ]; then
        ./scripts/drone-archive.sh "$project"
    fi
done
```

### Automated Backups
Add to crontab for weekly summaries:
```bash
# Weekly summary email (Sundays at 9am)
0 9 * * 0 /path/to/scripts/drone-summary.sh | mail -s "Drone Projects Weekly" you@email.com
```

## Workflow Timeline Example

**Day 1**: Shoot footage
- Import with `drone-import.sh`
- Review and delete obvious mistakes
- Edit README with location/conditions

**Days 2-7**: Edit project
- Work in DaVinci Resolve
- Create multiple exports
- Process select photos

**Day 8**: Archive project
- Run `drone-archive.sh`
- Finals upload to Dropbox
- Project moves to RecentlyCompleted

**Day 98**: 90-day review
- Decide: keep RAW or delete
- If keeping: upload to Dropbox as online-only
- If not: delete RAW, keep finals only

## Tips for Large Projects

### Multiple Shoot Days
```bash
# Import to same project
./scripts/drone-import.sh "BigProject_Day1"
./scripts/drone-import.sh "BigProject_Day2"
# Then combine in DaVinci
```

### Team Collaboration
1. Share Dropbox folder with team
2. Each person works on local copy
3. Sync finals back to shared folder
4. Use version numbers in exports

### Client Delivery
1. Create separate DELIVERY folder
2. Export client-specific versions
3. Share Dropbox link (not full project)
4. Keep RAW for 1 year minimum

## Safety & Backup

### 3-2-1 Rule
- **3 copies**: Original, External, Cloud
- **2 different media**: SSD + Cloud
- **1 offsite**: Dropbox

### Never Delete Until
- ✓ Verified on external drive
- ✓ Checksums match
- ✓ Finals in Dropbox
- ✓ 90 days have passed (for RAW)

### Emergency Recovery
If you accidentally delete:
1. Check Recently Completed folder
2. Check Dropbox's version history (30 days free)
3. Check if still on SD card
4. Use data recovery software (last resort)

## Support & Updates

### Getting Help
- Review this guide
- Check script comments
- Run scripts with no arguments for usage

### Customization
All scripts are well-commented and can be modified:
- Change retention periods
- Adjust compression settings
- Modify folder structures
- Add custom metadata

### Future Enhancements
Consider adding:
- GPS extraction to KML
- Thumbnail generation
- Automatic social media exports
- Integration with Adobe Premiere
- NAS storage support

## Quick Command Reference

```bash
# Import
./scripts/drone-import.sh "ProjectName"

# Check status
./scripts/drone-summary.sh

# Archive (finals only)
./scripts/drone-archive.sh "ProjectName"

# Archive (compressed)
./scripts/drone-archive.sh "ProjectName" --compress

# Archive (with RAW)
./scripts/drone-archive.sh "ProjectName" --keep-raw

# Project details
./scripts/drone-summary.sh "ProjectName"

# Manual paths
cd /Volumes/astroball/DroneProjects/ActiveProjects
cd ~/Dropbox/DroneFootage
```

---

*System created for efficient drone footage management with automatic organization, smart archiving, and flexible storage options.*