# Drone Footage Management System

Automated workflow for managing DJI drone footage with smart organization, cloud backup, and SD card cleanup.

## Features

- 🎯 **Smart Date Detection** - Automatically detects dates from DJI files and organizes accordingly
- 📁 **Automatic Separation** - Videos, photos, panoramas, and telemetry organized into separate folders
- ☁️ **Dropbox Integration** - Automatic cloud backup with online-only option to save space
- 🧹 **Safe Cleanup** - Verifies backup before deleting from SD card
- 📊 **Project Tracking** - View all projects and storage usage at a glance

## Configuration

By default footage is imported to `~/Dropbox/DroneFootage`. To import somewhere
else (no Dropbox, an external drive, a local folder), create a `drone.conf` in
the repo root:

```bash
DRONE_DEST="$HOME/Movies/DroneFootage"
```

All scripts read their paths from `scripts/drone-config.sh`. Settings, highest
precedence first:

| Setting | Meaning | Default |
|---------|---------|---------|
| `DRONE_DEST` | Where imports land | `~/Dropbox/DroneFootage` |
| `DRONE_SD_ROOT` | SD card mount point | `/Volumes/DJI` |
| `DRONE_SD_PATH` | DJI folder on the card | `$DRONE_SD_ROOT/DCIM/DJI_001` |

Precedence: environment variable → `<repo>/drone.conf` → `~/.drone.conf` →
default. `drone.conf` is gitignored, so it stays machine-specific.

## Quick Start

### 1. Import Footage from SD Card
```bash
cd ~/Documents/workspace/github/drone-footage-manager
./scripts/drone-import-smart.sh
```
Choose option 1 to use the auto-detected date, or skip the prompt entirely and
give every flight date its own folder:
```bash
./scripts/drone-import-smart.sh --all-dates
./scripts/drone-import-smart.sh --date 20260718   # just one date
```
Imports use `rsync`, so an interrupted run can simply be re-run — files already
copied are skipped.

### 2. Verify the Copy
```bash
./scripts/drone-verify.sh
```
Checksums every file on the card against its imported copy. Do this before
deleting anything. (If importing to Dropbox, wait for the menu bar icon to say
"Up to date" first.)

### 3. Clean SD Card
```bash
./scripts/drone-cleanup-sd.sh 20251115  # Use the flight date YYYYMMDD
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

Your footage will be organized under `$DRONE_DEST` like this:

```
$DRONE_DEST/
├── 2025/
│   └── 11-November/
│       └── 2025-11-15_Drone_Footage/
│           ├── VIDEO/
│           │   ├── RAW/        (MP4 files)
│           │   ├── SRT/        (GPS telemetry)
│           │   ├── LRF/        (Low-res proxies for fast editing)
│           │   └── HYPERLAPSE/ (Hyperlapse frame sets)
│           ├── PHOTOS/
│           │   ├── RAW/      (JPG files)
│           │   └── PANORAMA/ (Panorama sets)
│           └── METADATA/     (File lists, notes)
```

Hyperlapse and panorama sets live outside `DCIM/DJI_001` and have no date in
their folder name. They are matched back to the right flight date via the DJI
sequence index in the set name (`001_0567` → the date of clip `0567`).

## Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **drone-import-smart.sh** | Smart import with auto date detection | `./scripts/drone-import-smart.sh [--all-dates\|--date YYYYMMDD]` |
| **drone-verify.sh** | Checksum imported files against the card | `./scripts/drone-verify.sh [YYYYMMDD]` |
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