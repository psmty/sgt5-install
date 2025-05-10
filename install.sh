#!/bin/bash

set -e
trap "clear; exit" INT TERM EXIT

TITLE="SGT5 Installation Wizard"
WIDTH=60
HEIGHT=15
PRIVATE_REPO="psmty/sgt5-docker"

# 🚫 Check if current directory is completely empty
if [ "$(ls -A1)" ]; then
    dialog --clear --backtitle "$TITLE" --title "🚫 Directory Not Empty" \
        --msgbox "This script must be run in an EMPTY directory.\n\nPlease create a new folder and try again." $HEIGHT $WIDTH
    clear
    echo "❌ Current directory is not empty. Exiting."
    exit 1
fi

# Welcome screen
dialog --clear --backtitle "$TITLE" --title "$TITLE" --yesno "Welcome to the SGT5 installation wizard.\n\nThis script will download the required files from the private repository.\n\nDo you want to continue?" $HEIGHT $WIDTH
if [ $? -ne 0 ]; then
    clear
    echo "❌ Installation cancelled."
    exit 1
fi

# Ask for GitHub token
TMP_TOKEN=$(mktemp)
dialog --clear --backtitle "$TITLE" --title "GitHub Token" --inputbox "Enter your GitHub Personal Access Token:" $HEIGHT $WIDTH 2>"$TMP_TOKEN"
if [ $? -ne 0 ]; then
    clear
    echo "❌ Token input cancelled."
    exit 1
fi
GITHUB_TOKEN=$(<"$TMP_TOKEN")
rm "$TMP_TOKEN"

# Prepare temp folder
TEMP_DIR=".tmp_clone_$(date +%s)"

# Show fake gauge progress during clone
{
    echo 20
    sleep 0.2
    echo 40
    sleep 0.2
    echo 60
    sleep 0.2
    echo 80
    sleep 0.2
    echo 100
} | dialog --gauge "📥 Cloning $PRIVATE_REPO into temporary folder..." 8 $WIDTH 0 &

# Perform actual git clone
git clone "https://$GITHUB_TOKEN@github.com/$PRIVATE_REPO.git" "$TEMP_DIR" >/dev/null 2>&1

# Move contents from temp folder to current directory
shopt -s dotglob
mv "$TEMP_DIR"/* .
rm -rf "$TEMP_DIR"

# Clean git tracking info
rm -rf .git .gitignore

# Run start.sh with --init silently
if [ -f "./start.sh" ]; then
    chmod +x ./start.sh
    ./start.sh --init
else
    echo "⚠️ start.sh not found in the cloned repo."
    exit 1
fi
