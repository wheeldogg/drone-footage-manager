# Drone Footage Management System

Automated workflow for managing DJI drone footage with smart organization, cloud backup, and SD card cleanup.

## Features

- 🎯 **Smart Date Detection** - Automatically detects dates from DJI files and organizes accordingly
- 📁 **Automatic Separation** - Videos, photos, panoramas, and telemetry organized into separate folders
- ☁️ **Dropbox Integration** - Automatic cloud backup with online-only option to save space
- 🧹 **Safe Cleanup** - Verifies backup before deleting from SD card
- 📊 **Project Tracking** - View all projects and storage usage at a glance

## Quick Start

### 1. Import Footage from SD Card
```bash
cd ~/Documents/workspace/projects/wheeldogg_channel
./scripts/drone-import-smart.sh
```
Choose option 1 to use auto-detected date

### 2. Wait for Dropbox Sync
Check the Dropbox icon in your menu bar until it says "Up to date"

### 3. Clean SD Card
```bash
./scripts/drone-cleanup-sd.sh 20251115  # Use today's date YYYYMMDD
```

That's it! Your footage is backed up and SD card is ready for the next flight.

## Installation

### Prerequisites
- macOS (tested on Darwin 24.0.0)
- Dropbox account with desktop app installed
- DJI drone with SD card

### Setup
```bash
# Clone the repository
git clone https://github.com/wheeldogg/drone-footage-manager.git
cd drone-footage-manager

# Make scripts executable
chmod +x scripts/*.sh

# Optional: Install helpful tools
brew install terminal-notifier pv ffmpeg

# Optional: Run improvements setup
./setup-improvements.sh
```

## File Organization

Your footage will be organized in Dropbox like this:

```
~/Dropbox/DroneFootage/
├── 2025/
│   └── 11-November/
│       └── 2025-11-15_Drone_Footage/
│           ├── VIDEO/
│           │   ├── RAW/      (MP4 files)
│           │   └── SRT/      (GPS telemetry)
│           ├── PHOTOS/
│           │   ├── RAW/      (JPG files)
│           │   └── PANORAMA/ (Panorama sets)
│           └── METADATA/     (File lists, notes)
```

## Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **drone-import-smart.sh** | Smart import with auto date detection | `./scripts/drone-import-smart.sh` |
| **drone-import-dropbox.sh** | Direct to Dropbox (low disk space) | `./scripts/drone-import-dropbox.sh "Name"` |
| **drone-cleanup-sd.sh** | Safely delete from SD card | `./scripts/drone-cleanup-sd.sh 20251115` |
| **drone-summary.sh** | View all projects and stats | `./scripts/drone-summary.sh` |
| **fix-mixed-dates.sh** | Separate mixed date folders | `./scripts/fix-mixed-dates.sh` |

## Documentation

- **README.md** - This file (overview)
- **DRONE_SD_WORKFLOW.md** - Complete workflow guide
- **QUICK_COMMANDS.txt** - Quick reference card
- **SPEC.md** - Technical specification
- **IMPROVEMENTS.md** - Suggested enhancements

## Common Scenarios

### Multiple Dates on One SD Card
The smart import will detect this and give you options:
1. Combine all dates into one folder
2. **Import each date separately** (recommended)
3. Enter custom name

### Mac Running Out of Space
Use direct Dropbox import:
```bash
./scripts/drone-import-dropbox.sh "ProjectName"
```

After Dropbox syncs, right-click folders and select "Make Available Online-only"

### Check What's on SD Card
```bash
./scripts/drone-cleanup-sd.sh
# Shows dates and file counts without deleting
```

### Fix Mixed Dates Bug
If files from multiple dates ended up in one folder:
```bash
./scripts/fix-mixed-dates.sh
# Choose option 1 to separate
```

## Storage Tips

### Free Up Mac Space
After Dropbox syncs:
1. Open Finder → `~/Dropbox/DroneFootage/`
2. Right-click `VIDEO/RAW/` folder
3. Select "Make Available Online-only"
4. Repeat for `PHOTOS/RAW/`

Files stay in cloud but don't use local disk space.

### SD Card Management
- **Import same day** as flight
- **Keep recent footage** on card as backup
- **Format weekly** for best performance
- **Never delete** before Dropbox shows "Up to date"

## Testing

Tested with:
- DJI Mini 3 Pro
- 119GB SD card
- macOS Sonoma (Darwin 24.0.0)
- Dropbox Plus (2TB)

Sample test import:
- 1 video (1.7GB)
- 34 photos
- 1 telemetry file
- Total import time: ~30 seconds
- Date correctly detected: 2025-11-15

## Troubleshooting

### SD Card Not Found
```bash
ls /Volumes/
# Should show "DJI"
```

If not mounted, unplug/replug SD card reader

### Import Failed - Low Disk Space
Use direct Dropbox import which processes files one at a time:
```bash
./scripts/drone-import-dropbox.sh "ProjectName"
```

### Wrong Date Detected
The script reads dates from DJI filenames (format: `DJI_YYYYMMDDHHMMSS_####_D.MP4`). If dates are wrong, check your drone's clock settings.

### Dropbox Not Syncing
```bash
# Check status
dropbox status

# Restart Dropbox
dropbox stop && dropbox start
```

## Contributing

Contributions welcome! See [IMPROVEMENTS.md](IMPROVEMENTS.md) for suggested enhancements.

## Workflow Summary

```
┌─────────────┐
│  Fly Drone  │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  Insert SD Card │
└────────┬────────┘
         │
         ▼
┌──────────────────────┐
│ drone-import-smart.sh│ ← Auto-detects dates
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Wait for Dropbox    │
│      Sync            │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ drone-cleanup-sd.sh  │ ← Verifies backup first
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  SD Card Ready for   │
│    Next Flight! 🚁   │
└──────────────────────┘
```

## License

MIT License - Free to use and modify

## Author

Created for efficient drone footage management. Tested and working as of November 2025.

## Support

For issues or questions, see the documentation files:
- Quick help: `QUICK_COMMANDS.txt`
- Full guide: `DRONE_SD_WORKFLOW.md`
- Technical details: `SPEC.md`