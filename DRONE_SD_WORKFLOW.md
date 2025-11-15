# Drone SD Card Workflow - Complete Guide

## Quick Reference (What You'll Use Most)

### 📥 **STEP 1: Import Footage from SD Card**
```bash
cd ~/Documents/workspace/projects/wheeldogg_channel

# Smart import (auto-detects dates)
./scripts/drone-import-smart.sh

# OR direct import to Dropbox (for low disk space)
./scripts/drone-import-dropbox.sh "YYYY-MM-DD_ProjectName"
```

### 🗑️ **STEP 2: Clean Up SD Card**
```bash
# See what's on the SD card
./scripts/drone-cleanup-sd.sh

# Delete specific date (after verifying backup)
./scripts/drone-cleanup-sd.sh 20251109  # Deletes Nov 9, 2025 files
```

### 📊 **STEP 3: Check Status**
```bash
# View all projects
./scripts/drone-summary.sh

# Check specific project
./scripts/drone-summary.sh "ProjectName"
```

---

## Complete Workflow (Start to Finish)

### 🚁 **After Each Drone Flight**

#### 1. **Insert SD Card**
Your DJI SD card should mount at `/Volumes/DJI/`

#### 2. **Import Footage**
Choose based on your situation:

**Option A: Smart Import (Recommended)**
```bash
cd ~/Documents/workspace/projects/wheeldogg_channel
./scripts/drone-import-smart.sh
```
This will:
- Auto-detect dates from your files
- Show you options:
  1. Use auto-detected name (e.g., "2025-11-09_Drone_Footage")
  2. Import each date separately
  3. Enter custom name

**Option B: Direct to Dropbox (When Mac is Low on Space)**
```bash
./scripts/drone-import-dropbox.sh "2025-11-10_Beach_Flight"
```
- Copies directly to Dropbox folder
- Processes one file at a time to save space
- Takes ~20-30 minutes for 30GB

#### 3. **Wait for Dropbox Sync**
- Check Dropbox icon in menu bar
- Wait until it says "Up to date"

#### 4. **Free Up Local Space (Optional)**
After Dropbox finishes syncing:
1. Open Finder → `~/Dropbox/DroneFootage/`
2. Right-click on `VIDEO/RAW/` folder
3. Select "Make Available Online-only"
4. Repeat for `PHOTOS/RAW/`

This keeps files in cloud but removes from Mac

#### 5. **Clean SD Card**
```bash
# Check what's on SD card
./scripts/drone-cleanup-sd.sh

# Output shows:
#   2025-11-09: 23 files
#   2025-11-10: 105 files

# Delete specific date
./scripts/drone-cleanup-sd.sh 20251109  # Deletes Nov 9

# Or delete all (format card in drone is better)
```

---

## File Organization

### **Dropbox Structure**
```
~/Dropbox/DroneFootage/
├── 2025/
│   ├── 11-November/
│   │   ├── 2025-11-09_Drone_Footage/
│   │   │   ├── VIDEO/
│   │   │   │   ├── RAW/        (MP4 files)
│   │   │   │   └── SRT/        (GPS telemetry)
│   │   │   ├── PHOTOS/
│   │   │   │   ├── RAW/        (JPG files)
│   │   │   │   └── PANORAMA/   (Panorama sets)
│   │   │   └── METADATA/       (File lists, notes)
│   │   └── 2025-11-10_Beach_Flight/
│   └── 12-December/
└── Archive/
```

### **What Gets Separated**
- **Videos** → VIDEO/RAW/
- **Photos** → PHOTOS/RAW/
- **Panoramas** → PHOTOS/PANORAMA/
- **GPS Data** → VIDEO/SRT/

---

## Common Scenarios

### **Scenario 1: Normal Import After Flight**
```bash
# 1. Insert SD card
# 2. Import with smart detection
./scripts/drone-import-smart.sh

# 3. Choose option 1 (auto-detected name)
# 4. Wait for import (~10-15 minutes for 30GB)
# 5. Clean up old dates from SD
./scripts/drone-cleanup-sd.sh 20251109
```

### **Scenario 2: Mac Almost Full**
```bash
# Use direct Dropbox import
./scripts/drone-import-dropbox.sh "2025-11-10_Flight"

# After Dropbox syncs, make online-only:
# Right-click folders in Finder → "Make Available Online-only"
```

### **Scenario 3: Multiple Days on One Card**
```bash
# Smart import will detect this
./scripts/drone-import-smart.sh

# Choose option 2: "Import each date separately"
# Creates separate folders for each date
```

### **Scenario 4: Fix Mixed Dates (Current Bug)**
```bash
# If dates got mixed (like your Nov 9/10 issue)
./scripts/fix-mixed-dates.sh

# Choose option 1: Separate into different folders
```

---

## Scripts Reference

### **drone-import-smart.sh**
- **What**: Auto-detects dates and imports intelligently
- **When**: Use this for most imports
- **Options**:
  - Auto name based on dates
  - Separate by date
  - Custom name

### **drone-import-dropbox.sh**
- **What**: Direct import to Dropbox (saves Mac space)
- **When**: Mac is low on space
- **Usage**: `./drone-import-dropbox.sh "ProjectName"`

### **drone-cleanup-sd.sh**
- **What**: Safely delete files from SD card
- **When**: After verifying Dropbox backup
- **Usage**:
  - `./drone-cleanup-sd.sh` - Show what's on card
  - `./drone-cleanup-sd.sh 20251110` - Delete Nov 10 files

### **drone-summary.sh**
- **What**: View all projects and storage status
- **When**: Check what you have
- **Usage**: `./drone-summary.sh`

### **fix-mixed-dates.sh**
- **What**: Fix when multiple dates in one folder
- **When**: If import bug mixed dates
- **Usage**: `./fix-mixed-dates.sh`

---

## Tips & Best Practices

### ✅ **DO**
- Import footage same day as flight
- Wait for Dropbox to finish syncing before deleting
- Use "Make Available Online-only" to save Mac space
- Keep recent footage on SD as backup until next flight
- Name projects descriptively (Beach_Sunset not just "Flight1")

### ❌ **DON'T**
- Don't format SD card until Dropbox shows "Up to date"
- Don't import if Mac has less than 10GB free
- Don't delete from SD without verifying backup
- Don't mix multiple projects in same import

### 💡 **PRO TIPS**
1. **Check Before Flying**: Run cleanup script to see available space
2. **Batch by Location**: Import all shots from one location together
3. **Weekly Cleanup**: Review and clean SD card weekly
4. **Monthly Archive**: Move old projects to external drive monthly

---

## Troubleshooting

### **SD Card Not Found**
```bash
# Check if mounted
ls /Volumes/
# Should see "DJI"

# If not, try:
# 1. Unplug and replug SD card reader
# 2. Check card in drone
# 3. Try different USB port
```

### **Import Failed**
```bash
# Check disk space
df -h ~

# If low, use direct Dropbox import:
./scripts/drone-import-dropbox.sh "ProjectName"
```

### **Dropbox Not Syncing**
```bash
# Check Dropbox status
dropbox status

# Restart Dropbox
dropbox stop
dropbox start
```

### **Wrong Dates in Folder**
```bash
# Use the fix script
./scripts/fix-mixed-dates.sh

# Choose option 1 to separate dates
```

---

## Quick Daily Workflow

### **Morning (Before Flying)**
```bash
# Check SD card space
ls /Volumes/DJI
./scripts/drone-cleanup-sd.sh
```

### **After Flying**
```bash
# Import footage
cd ~/Documents/workspace/projects/wheeldogg_channel
./scripts/drone-import-smart.sh

# Wait for Dropbox sync
# Check menu bar icon
```

### **Evening (Cleanup)**
```bash
# After Dropbox synced
./scripts/drone-cleanup-sd.sh 20251110  # Today's date

# Make Dropbox files online-only
# Right-click in Finder → "Make Available Online-only"
```

---

## Storage Management

### **Current Setup**
- **SD Card**: 119GB (enough for ~3-4 flights)
- **Mac**: Limited space (use online-only)
- **Dropbox**: Your cloud backup

### **Space Estimates**
- **Per Flight**: 10-30GB typical
- **After Import**: Files in Dropbox
- **After Online-Only**: ~0GB on Mac
- **SD After Cleanup**: Ready for next flight

---

## Summary - Your 3-Step Process

Every time you fly:

1. **IMPORT**
   ```bash
   ./scripts/drone-import-smart.sh
   ```

2. **WAIT** for Dropbox sync

3. **CLEAN**
   ```bash
   ./scripts/drone-cleanup-sd.sh 20251110
   ```

That's it! Your footage is organized, backed up, and your SD card is ready for the next flight.

---

*Last Updated: November 2025*
*Scripts Location: ~/Documents/workspace/projects/wheeldogg_channel/scripts/*