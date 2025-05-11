#!/bin/bash

set -e
trap "clear; exit" INT TERM EXIT

TITLE="SGT5 Installation Wizard"
WIDTH=60
HEIGHT=15
PRIVATE_REPO="psmty/sgt5-docker"

# Ensure essential tools (dialog, fzf) are installed
sudo apt-get update -y >/dev/null
sudo apt-get install -y dialog fzf curl unzip zip >/dev/null

# Check if current directory is completely empty
if [ "$(ls -A1)" ]; then
    dialog --clear --backtitle "$TITLE" --title "⚠️ Directory Not Empty" \
        --msgbox "This script must be run in an EMPTY directory.\n\nPlease create a new folder and try again." $HEIGHT $WIDTH
    clear
    echo "⚠️ Current directory is not empty. Exiting."
    exit 1
fi

# Welcome screen
dialog --clear --backtitle "$TITLE" --title "$TITLE" --yesno "Welcome to the SGT5 installation wizard.\n\nThis script will download the required files from the private repository.\n\nDo you want to continue?" $HEIGHT $WIDTH
if [ $? -ne 0 ]; then
    clear
    echo "❌ Installation cancelled."
    exit 1
fi

# Ask for prerequisites installation
dialog --clear --backtitle "$TITLE" --title "Install Prerequisites" --yesno "Before continuing, we need to install all required packages (Docker, AzCopy, etc).\n\nThis operation may take a few minutes.\n\nDo you want to continue?" $HEIGHT $WIDTH
if [ $? -ne 0 ]; then
    clear
    echo "⚠️ Prerequisites installation cancelled."
    exit 1
fi

# === Embedded prerequisites.sh ===

# Load environment variables from .env if exists
if [ -f ./sgt5_core/.env ]; then
  set -o allexport
  source ./sgt5_core/.env
  set +o allexport
fi

# Function to install a package if not installed
install_if_missing() {
  local pkg="$1"
  if ! dpkg -s "$pkg" &>/dev/null; then
    echo "🔧 Installing $pkg..."
    sudo apt-get install -y "$pkg"
  else
    echo "✅ $pkg already installed."
  fi
}

# Create directories
sudo mkdir -p $STORAGE_ROOT/db/mssql/{backup,data,log,secrets}
sudo mkdir -p $STORAGE_ROOT/backups/mssql
sudo mkdir -p $STORAGE_ROOT/logs/cron
sudo mkdir -p $STORAGE_ROOT/settings
sudo chmod 777 -R $SGT5_INSTALLATION_FOLDER

# Install base packages
for pkg in unzip zip curl ca-certificates; do
  install_if_missing "$pkg"
done

# Install azcopy
if ! command -v azcopy &>/dev/null; then
  echo "Installing azcopy..."
  AZCOPY_TEMP_DIR=$(mktemp -d)
  curl -sL https://aka.ms/downloadazcopy-v10-linux -o "$AZCOPY_TEMP_DIR/azcopy.tar.gz"
  tar -xzf "$AZCOPY_TEMP_DIR/azcopy.tar.gz" -C "$AZCOPY_TEMP_DIR"
  AZCOPY_EXTRACTED_DIR=$(find "$AZCOPY_TEMP_DIR" -type d -name "azcopy_linux_amd64*" | head -n 1)
  sudo cp "$AZCOPY_EXTRACTED_DIR/azcopy" /usr/local/bin/
  sudo chmod +x /usr/local/bin/azcopy
  rm -rf "$AZCOPY_TEMP_DIR"
  echo "✅ azcopy installed."
fi

# Install Docker
if ! command -v docker &>/dev/null; then
  echo "Installing Docker..."
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg || true
  done
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker $USER
  echo "✅ Docker installed."
  REBOOT_NEEDED=true
else
  echo "✅ Docker already installed."
  REBOOT_NEEDED=false
fi

if [ "$REBOOT_NEEDED" = true ]; then
    dialog --clear --backtitle "$TITLE" --title "Reboot Required" \
        --yesno "Prerequisites installed successfully.\n\nA system reboot is required because Docker was just installed.\n\nDo you want to reboot now?" $HEIGHT $WIDTH

    if [ $? -eq 0 ]; then
        clear
        echo "🔁 Rebooting now..."
        sleep 1
        echo "Please run the installer again after reboot with:"
        echo "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)\""
        sleep 2
        sudo reboot
    else
        dialog --clear --backtitle "$TITLE" --title "Manual Restart" \
            --msgbox "You chose not to reboot now.\n\nPlease reboot manually and run this install script again:\n\n/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)\"" $HEIGHT $WIDTH
        clear
        exit 0
    fi
fi

dialog --clear --backtitle "$TITLE" --title "Reboot Required" \
    --yesno "Prerequisites installed successfully.\n\nA system reboot is required before continuing.\n\nDo you want to reboot now?" $HEIGHT $WIDTH

if [ $? -eq 0 ]; then
    clear
    echo "🔁 Rebooting now..."
    sleep 1
    echo "Please run the installer again after reboot with:"
    echo "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)\""
    sleep 2
    sudo reboot
else
    dialog --clear --backtitle "$TITLE" --title "Manual Restart" \
        --msgbox "You chose not to reboot now.\n\nPlease reboot manually and run this install script again:\n\n/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)\"" $HEIGHT $WIDTH
    clear
    exit 0
fi
