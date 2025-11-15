#!/bin/bash

# setup-improvements.sh - Quick setup for immediate workflow improvements
# Run this once to add quality-of-life enhancements

echo "========================================="
echo "Drone Workflow - Quick Improvements Setup"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
    SHELL_NAME="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bash_profile"
    SHELL_NAME="bash"
else
    SHELL_RC="$HOME/.profile"
    SHELL_NAME="sh"
fi

echo -e "${BLUE}Detected shell: $SHELL_NAME${NC}"
echo -e "${BLUE}Config file: $SHELL_RC${NC}"

# 1. Add aliases to shell configuration
echo -e "\n${GREEN}1. Adding drone command aliases...${NC}"

# Check if aliases already exist
if grep -q "drone-import" "$SHELL_RC" 2>/dev/null; then
    echo "  Aliases already configured"
else
    cat >> "$SHELL_RC" <<'EOF'

# ============================================
# Drone Workflow Shortcuts (added by setup)
# ============================================

# Quick access to drone scripts
alias drone-import='~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-import.sh'
alias drone-archive='~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-archive.sh'
alias drone-status='~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-summary.sh'
alias drone-cd='cd /Volumes/astroball/DroneProjects/ActiveProjects && ls -la'

# Main drone command for easy access
drone() {
    case "$1" in
        import|i)
            shift
            ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-import.sh "$@"
            ;;
        archive|a)
            shift
            ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-archive.sh "$@"
            ;;
        status|s)
            shift
            ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-summary.sh "$@"
            ;;
        cd)
            cd /Volumes/astroball/DroneProjects/ActiveProjects
            ls -la
            ;;
        help|h)
            echo "Drone Workflow Commands:"
            echo "  drone import [name]  - Import footage from SD card"
            echo "  drone archive [name] - Archive completed project"
            echo "  drone status [name]  - View project status"
            echo "  drone cd            - Go to active projects folder"
            echo ""
            echo "Shortcuts: i=import, a=archive, s=status, h=help"
            ;;
        *)
            echo "Usage: drone {import|archive|status|cd|help} [args]"
            echo "Try 'drone help' for more information"
            ;;
    esac
}

# Quick status check
alias ds='drone status'

# Go to scripts directory
alias drone-scripts='cd ~/Documents/workspace/projects/wheeldogg_channel/scripts'

EOF
    echo -e "  ${GREEN}✓ Aliases added to $SHELL_RC${NC}"
fi

# 2. Install recommended tools
echo -e "\n${GREEN}2. Checking for recommended tools...${NC}"

check_and_install() {
    local tool=$1
    local brew_name=$2
    local description=$3

    if command -v $tool &> /dev/null; then
        echo -e "  ✓ $tool already installed"
    else
        echo -e "  ${YELLOW}$tool not found. $description${NC}"
        if command -v brew &> /dev/null; then
            read -p "  Install $tool? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                brew install $brew_name
            fi
        else
            echo "  Install with: brew install $brew_name"
        fi
    fi
}

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "  ${YELLOW}Homebrew not found. Install from https://brew.sh${NC}"
    echo "  After installing Homebrew, run this setup again."
else
    check_and_install "terminal-notifier" "terminal-notifier" "Enables desktop notifications"
    check_and_install "pv" "pv" "Shows progress bars during file operations"
    check_and_install "parallel" "parallel" "Speeds up file copying"
    check_and_install "ffmpeg" "ffmpeg" "Required for video compression"
fi

# 3. Create quick launcher script
echo -e "\n${GREEN}3. Creating quick launcher...${NC}"

mkdir -p ~/bin

cat > ~/bin/drone-quick <<'EOF'
#!/bin/bash
# Quick interactive launcher for drone workflow

clear
echo "================================"
echo "   DRONE WORKFLOW LAUNCHER"
echo "================================"
echo ""

# Check if SD card is mounted
if [ -d "/Volumes/DJI" ]; then
    echo "✓ DJI SD card detected"
    echo ""
fi

# Check external drive
if [ -d "/Volumes/astroball" ]; then
    echo "✓ External drive connected"
else
    echo "⚠ External drive not found"
fi

echo ""
echo "What would you like to do?"
echo ""
echo "1) Import footage from SD card"
echo "2) Archive completed project"
echo "3) View project status"
echo "4) Go to active projects folder"
echo "5) View quick help"
echo "6) Exit"
echo ""
read -p "Enter choice [1-6]: " choice

case $choice in
    1)
        if [ -d "/Volumes/DJI" ]; then
            echo ""
            read -p "Enter project name (or press Enter for auto-name): " name
            if [ -z "$name" ]; then
                name="$(date +%Y-%m-%d)_$(date +%H%M)_Flight"
                echo "Using auto-generated name: $name"
            fi
            ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-import.sh "$name"
        else
            echo "Please insert DJI SD card first"
            read -p "Press Enter to continue..."
        fi
        ;;
    2)
        echo ""
        echo "Recent projects:"
        ls -1t /Volumes/astroball/DroneProjects/ActiveProjects 2>/dev/null | head -5
        echo ""
        read -p "Enter project name to archive: " name
        ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-archive.sh "$name"
        ;;
    3)
        ~/Documents/workspace/projects/wheeldogg_channel/scripts/drone-summary.sh
        read -p "Press Enter to continue..."
        ;;
    4)
        cd /Volumes/astroball/DroneProjects/ActiveProjects
        echo "Switched to: $(pwd)"
        exec $SHELL
        ;;
    5)
        echo ""
        echo "QUICK HELP:"
        echo "-----------"
        echo "• Import: Copies footage from SD card, organizes by type"
        echo "• Archive: Moves to completed, uploads finals to Dropbox"
        echo "• Status: Shows all projects and storage usage"
        echo ""
        echo "Shortcuts from terminal:"
        echo "  drone import [name]"
        echo "  drone archive [name]"
        echo "  drone status"
        echo ""
        read -p "Press Enter to continue..."
        ;;
    6)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        read -p "Press Enter to continue..."
        ;;
esac

# Re-run the menu
exec "$0"
EOF

chmod +x ~/bin/drone-quick

if [ -d ~/bin ]; then
    echo -e "  ${GREEN}✓ Quick launcher created at ~/bin/drone-quick${NC}"
fi

# 4. Add notification support to existing scripts
echo -e "\n${GREEN}4. Adding notification support...${NC}"

# Create notification helper
cat > ~/Documents/workspace/projects/wheeldogg_channel/scripts/notify.sh <<'EOF'
#!/bin/bash
# Notification helper for drone scripts

notify() {
    local title="$1"
    local message="$2"
    local sound="${3:-default}"

    # Try terminal-notifier first
    if command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "$title" -message "$message" -sound "$sound" 2>/dev/null
    # Fall back to osascript
    elif command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
    fi

    # Always echo to terminal as well
    echo "[$title] $message"
}

# Export function for use in other scripts
export -f notify
EOF

chmod +x ~/Documents/workspace/projects/wheeldogg_channel/scripts/notify.sh
echo -e "  ${GREEN}✓ Notification helper created${NC}"

# 5. Create desktop shortcut
echo -e "\n${GREEN}5. Creating desktop shortcut (optional)...${NC}"
read -p "Create desktop shortcut for quick launcher? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    cat > ~/Desktop/Drone\ Workflow.command <<'EOF'
#!/bin/bash
# Drone Workflow Desktop Launcher
cd ~/Documents/workspace/projects/wheeldogg_channel
exec ~/bin/drone-quick
EOF
    chmod +x ~/Desktop/Drone\ Workflow.command
    echo -e "  ${GREEN}✓ Desktop shortcut created${NC}"
fi

# 6. Summary
echo -e "\n${BLUE}=========================================${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${BLUE}=========================================${NC}"

echo -e "\n${YELLOW}What's been added:${NC}"
echo "1. Terminal shortcuts (drone, drone-import, etc.)"
echo "2. Quick launcher at ~/bin/drone-quick"
echo "3. Notification support for alerts"
if [ -f ~/Desktop/Drone\ Workflow.command ]; then
    echo "4. Desktop shortcut for easy access"
fi

echo -e "\n${YELLOW}To activate the new commands:${NC}"
echo -e "${GREEN}source $SHELL_RC${NC}"
echo ""
echo "Or just open a new terminal window."

echo -e "\n${YELLOW}Quick Commands:${NC}"
echo "  drone import        - Import from SD card"
echo "  drone archive       - Archive project"
echo "  drone status        - View all projects"
echo "  drone-quick         - Interactive menu"

echo -e "\n${YELLOW}Next time you connect an SD card:${NC}"
echo "  Just type: ${GREEN}drone import${NC}"

echo -e "\n${BLUE}Full documentation: DRONE_WORKFLOW_GUIDE.md${NC}"
echo -e "${BLUE}Improvements list: IMPROVEMENTS.md${NC}"