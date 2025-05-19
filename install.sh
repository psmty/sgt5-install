#!/bin/bash

set -e

TITLE="SGT5 Installation Wizard"
WIDTH=80
HEIGHT=15
PRIVATE_REPO="psmty/sgt5-docker"

echo "Initializing installation..."

# Check if current directory is root "/"
if [[ "$PWD" == "/" ]]; then
    echo "[ERROR] You are in the root (/) directory. Aborting to prevent dangerous operations."
    echo "Please create a new folder and try again."
    exit 1
fi

sudo chmod 777 -R .

# Ensure essential tools (dialog, fzf) are installed if missing
MISSING_PACKAGES=()
for pkg in dialog fzf; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
    echo "Installing missing packages: ${MISSING_PACKAGES[*]}..."
    sudo apt-get update -y >/dev/null
    sudo apt-get install -y "${MISSING_PACKAGES[@]}" >/dev/null
else
    echo "✅ All required packages are already installed."
fi

# Check if current directory is completely empty
if [ "$(ls -A1)" ]; then
    # Check if sgt5_core directory exists
    if [ -d "./sgt5_core" ]; then
        rm -rf ./sgt5_core
    else
        dialog --clear --backtitle "$TITLE" --title "⚠️ Directory Not Empty" \
            --msgbox "This script must be run in an EMPTY directory.\n\nPlease create a new folder and try again." $HEIGHT $WIDTH
        clear
        echo "⚠️ Current directory is not empty. Exiting."
        exit 1
    fi
fi

# Welcome screen
dialog --clear --backtitle "$TITLE" --title "$TITLE" --yesno "Welcome to the SGT5 installation wizard.\n\nThis script will download the required files from the private repository.\n\nDo you want to continue?" $HEIGHT $WIDTH
if [ $? -ne 0 ]; then
    clear
    echo "❌ Installation cancelled."
    exit 1
fi

# Ask for prerequisites installation
dialog --clear --backtitle "$TITLE" --title "Install Prerequisites" --yesno "Before continuing, we need to install the following required packages\n\n* docker\n* azcopy\n* openssl\n* 7zip\n* curl\n* ca-certificates\n\nThis operation may take a few minutes.\n\nDo you want to continue?" $HEIGHT $WIDTH
if [ $? -ne 0 ]; then
    clear
    echo "⚠️ Prerequisites installation cancelled."
    exit 1
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

# Install base packages
for pkg in curl ca-certificates p7zip-full openssl; do
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
REBOOT_NEEDED=false
if ! dpkg -s docker-ce >/dev/null 2>&1; then
    echo "Installing Docker..."
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt-get remove -y $pkg || true
    done
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    REBOOT_NEEDED=true
    echo "✅ Docker installed."
else
    echo "✅ Docker already installed."
fi

# Ensure current user is in docker group
if ! groups $USER | grep -q '\bdocker\b'; then
    echo "🔧 Adding $USER to docker group..."
    sudo usermod -aG docker $USER
    echo "⚠️ You need to log out and log back in for group changes to take effect."
fi

if [ "$REBOOT_NEEDED" = true ]; then
    dialog --clear --backtitle "$TITLE" --title "Reboot Required" \
        --yesno "Prerequisites installed successfully.\n\nA system reboot is required because Docker was just installed.\n\nDo you want to reboot now?" $HEIGHT $WIDTH

    if [ $? -eq 0 ]; then
        clear
        echo "🔁 Rebooting now..."
        sleep 1
        echo "Please run the installer again after reboot with:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)"'
        sleep 2
        sudo reboot
        exit 0
    else
        dialog --clear --backtitle "$TITLE" --title "Manual Restart" \
            --msgbox "You chose not to reboot now.\n\nPlease reboot manually and run this install script again:\n\n/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/psmty/sgt5-install/main/install.sh)\"" $HEIGHT $WIDTH
        clear
        exit 0
    fi
fi

# === If no reboot is required, continue with installation ===

# Ask for GitHub token (required)
while true; do
    TMP_TOKEN=$(mktemp)
    dialog --clear --backtitle "$TITLE" \
        --title "GitHub Token" \
        --inputbox "Enter your GitHub Personal Access Token (required):" $HEIGHT $WIDTH 2>"$TMP_TOKEN"

    if [ $? -ne 0 ]; then
        clear
        echo "❌ Token input cancelled."
        rm -f "$TMP_TOKEN"
        exit 1
    fi

    GITHUB_TOKEN=$(<"$TMP_TOKEN")
    rm -f "$TMP_TOKEN"

    if [[ -z "$GITHUB_TOKEN" ]]; then
        dialog --clear --backtitle "$TITLE" \
            --title "Missing Token" \
            --msgbox "GitHub token cannot be empty. Please enter a valid token." 7 60
    else
        break
    fi
done

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
} | dialog --gauge "📦 Cloning $PRIVATE_REPO into temporary folder..." 8 $WIDTH 0 &

# Perform actual git clone
git clone "https://$GITHUB_TOKEN@github.com/$PRIVATE_REPO.git" "$TEMP_DIR" >/dev/null 2>&1

# Move contents from temp folder to current directory
shopt -s dotglob
mv "$TEMP_DIR"/* .
rm -rf "$TEMP_DIR"

# Clean git tracking info
rm -rf .git .gitignore readme.md start.png

clear
tput reset

# Run start.sh with -i silently
if [ -f "./sgt5_core/start.sh" ]; then
    chmod +x ./sgt5_core/start.sh
    sleep 1
    ./sgt5_core/start.sh -i
else
    echo "❌ start.sh not found in the cloned repo."
    exit 1
fi
