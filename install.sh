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

# Ensure essential tools (dialog, fzf, jq) are installed if missing
MISSING_PACKAGES=()
for pkg in dialog fzf jq; do
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
        echo "sgt5_core folder will be updated"
    else
        dialog --clear --backtitle "$TITLE" --title "⚠️ Directory Not Empty" \
            --msgbox "This script must be run in an EMPTY directory.\n\nPlease create a new folder and try again." $HEIGHT $WIDTH
        clear
        echo "⚠️ Current directory is not empty. Exiting."
        exit 1
    fi
fi

# Development warning screen
dialog --clear --backtitle "$TITLE" --title "⚠️ DEVELOPMENT WARNING ⚠️" --yesno "🔴 ATTENTION: This is a DEVELOPMENT installer!\n\n⚠️ This installer is intended for DEVELOPMENT purposes ONLY.\n⚠️ DO NOT use this in production environments.\n⚠️ This may contain unstable features and experimental code.\n\n🔴 Use at your own risk!\n\nDo you understand and want to continue anyway?" $HEIGHT $WIDTH
if [ $? -ne 0 ]; then
    clear
    echo "❌ Development warning declined. Installation cancelled for safety."
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
dialog --clear --backtitle "$TITLE" --title "Install Prerequisites" --yesno "Before continuing, we need to install the following required packages\n\ndocker, azcopy, openssl, 7zip, gh, curl, btop, ca-certificates\n\nThis operation may take a few minutes.\n\nDo you want to continue?" $HEIGHT $WIDTH
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

fetch_ghcr_token_from_env_file() {
    local repo="psmty/sgt5-docker"
    local file_path=".env"
    local branch="main"
    local token="$1"

    local env_content
    env_content=$(curl -s -H "Authorization: token $token" \
        "https://raw.githubusercontent.com/$repo/$branch/$file_path")

    if [[ -z "$env_content" ]]; then
        echo "Failed to fetch .env file from repository"
        return 1
    fi

    local extracted_token
    extracted_token=$(echo "$env_content" | grep -E '^GHCR_TOKEN=' | cut -d '=' -f2-)

    if [[ -z "$extracted_token" ]]; then
        echo "GHCR_TOKEN not found in .env file"
        return 1
    fi

    echo "$extracted_token"
}

select_sgt5_version() {
    local GHCR_ORG="psmty"
    local GHCR_REPO="sgt5-images"
    local CONTAINER_NAME="web"

    for cmd in gh jq dialog; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            dialog --msgbox "❌ Required command not found: $cmd" 7 50
            return 1
        fi
    done

    if [[ -z "${GH_TOKEN:-}" ]]; then
        dialog --msgbox "❌ GitHub token (GH_TOKEN) is not set." 7 50
        return 1
    fi

    local versions=$(gh api -H "Accept: application/vnd.github.v3+json" \
        "/orgs/${GHCR_ORG}/packages/container/${GHCR_REPO}%2F${CONTAINER_NAME}/versions" 2>/dev/null)

    declare -A TAG_DATE_MAP
    local TAGS=()

    while read -r tag created; do
        [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        TAGS+=("$tag")
        TAG_DATE_MAP["$tag"]=$(date -d "$created" +%m/%d/%Y)
    done < <(echo "$versions" | jq -r '.[] | select(.metadata.container.tags != null) | .created_at as $created | .metadata.container.tags[] | "\(.),\($created)"' | tr ',' ' ')

    if [[ ${#TAGS[@]} -eq 0 ]]; then
        dialog --msgbox "❌ No valid version tags found." 7 50
        return 1
    fi

    local base_versions=$(printf "%s\n" "${TAGS[@]}" | cut -d '.' -f 1-3 | sort -u -Vr)
    local ITEMS=()

    for base in $base_versions; do
        ITEMS+=("$base" "")
    done

    local selected_base
    selected_base=$(dialog --clear --backtitle "SGT5 Version Selector" \
        --title "Select Base Version" \
        --menu "Choose a base version:" 20 60 15 \
        "${ITEMS[@]}" \
        2>&1 >/dev/tty) || return 1

    local BUILD_ITEMS=()
    for tag in "${TAGS[@]}"; do
        if [[ "$tag" == "$selected_base".* ]]; then
            local label="${TAG_DATE_MAP[$tag]}"
            BUILD_ITEMS+=("$tag" "$label")
        fi
    done

    if [[ ${#BUILD_ITEMS[@]} -eq 0 ]]; then
        dialog --msgbox "❌ No builds found for $selected_base." 7 50
        return 1
    fi

    local selected_build
    selected_build=$(dialog --clear --backtitle "SGT5 Version Selector" \
        --title "Select Build Version" \
        --menu "Choose a full version to install:" 20 70 15 \
        "${BUILD_ITEMS[@]}" \
        2>&1 >/dev/tty) || return 1

    echo "$selected_build"
}

get_latest_available_branch() {
    local token="$1"
    local repo="$2"
    local target="$3"
    local branches
    
    branches=$(curl -s -H "Authorization: token $token" \
        "https://api.github.com/repos/$repo/branches?per_page=100" | jq -r '.[].name' 2>/dev/null)
    
    if [[ -z "$branches" ]]; then
        echo "" # Return empty string if fetch failed
        return 1
    fi
    
    # If target is empty, get the latest semantic version branch with dev_ prefix
    if [[ -z "$target" ]]; then
        echo "$branches" | grep -E '^dev_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1
        return
    fi
    
    # First, try exact match with dev_ prefix
    if echo "$branches" | grep -q "^dev_$target$"; then
        echo "dev_$target"
        return
    fi
    
    # Extract major.minor.patch from target version (e.g., 9.3.1 from 9.3.1.365)
    local major_minor_patch=$(echo "$target" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
    
    if [[ -n "$major_minor_patch" ]]; then
        # Look for dev_ branches matching the same major.minor.patch pattern
        local matching_branch=$(echo "$branches" | grep -E "^dev_${major_minor_patch//./\\.}\\.[0-9]+$" | sort -V | awk -v t="dev_$target" '$1 <= t' | tail -n1)
        if [[ -n "$matching_branch" ]]; then
            echo "$matching_branch"
            return
        fi
        
        # If no matching branch found, try latest of that major.minor.patch with dev_ prefix
        local latest_same_pattern=$(echo "$branches" | grep -E "^dev_${major_minor_patch//./\\.}\\.[0-9]+$" | sort -V | tail -n1)
        if [[ -n "$latest_same_pattern" ]]; then
            echo "$latest_same_pattern"
            return
        fi
    fi
    
    # If nothing found so far, fallback to latest available version with dev_ prefix
    echo "$branches" | grep -E '^dev_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1
}

validate_github_token() {
    local token="$1"
    local response
    
    echo "Validating GitHub token..."
    response=$(curl -s -H "Authorization: token $token" https://api.github.com/user 2>/dev/null)
    
    if echo "$response" | jq -e '.login' >/dev/null 2>&1; then
        local username=$(echo "$response" | jq -r '.login')
        echo "Token validated for user: $username"
        return 0
    else
        echo "Invalid GitHub token"
        return 1
    fi
}

# Install base packages
for pkg in curl ca-certificates p7zip-full openssl btop gh; do
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
        # Validate token before proceeding
        if ! validate_github_token "$GITHUB_TOKEN"; then
            dialog --clear --backtitle "$TITLE" \
                --title "Invalid Token" \
                --msgbox "The GitHub token you entered is invalid or does not have sufficient permissions. Please try again with a valid token." 7 60
            continue
        fi
        break
    fi

done

clear
tput reset

GH_TOKEN="$(fetch_ghcr_token_from_env_file "$GITHUB_TOKEN")"

if [[ -z "$GH_TOKEN" ]]; then
    echo "Could not extract GHCR_TOKEN from remote .env file"
fi

export GH_TOKEN

TARGET_VERSION="$(select_sgt5_version)"
if [[ -z "${TARGET_VERSION:-}" ]]; then
    echo "Version selection failed or cancelled by user"
fi

FALLBACK_BRANCH=$(get_latest_available_branch "$GITHUB_TOKEN" "$PRIVATE_REPO" "$TARGET_VERSION")

if [[ -z "$FALLBACK_BRANCH" ]]; then
    echo "No suitable fallback branch found for version $TARGET_VERSION"
fi

echo "Using branch: $FALLBACK_BRANCH"

# Prepare temp folder
TEMP_DIR=".tmp_clone_$(date +%s)"

# Check if TEMP_DIR already exists (very unlikely, but safe)
if [ -d "$TEMP_DIR" ]; then
    echo "Temporary directory $TEMP_DIR already exists. Removing..."
    rm -rf "$TEMP_DIR"
fi

# Try git clone with better error handling
GIT_CLONE_URL="https://$GITHUB_TOKEN@github.com/$PRIVATE_REPO.git"
echo "Cloning the repository into temporary folder..."
if ! git clone --branch "$FALLBACK_BRANCH" --depth 1 "$GIT_CLONE_URL" "$TEMP_DIR"; then
    echo "[ERROR] Failed to clone repository. Please check your token, branch name, and network connection."
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Repository cloned successfully."

# Remove existing sgt5_core if present
if [ -d "./sgt5_core" ]; then
    echo "Removing existing sgt5_core directory..."
    rm -rf ./sgt5_core
fi

# Check if sgt5_core exists in the cloned repo
if [ ! -d "$TEMP_DIR/sgt5_core" ]; then
    echo "[ERROR] sgt5_core directory not found in the cloned repository."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Move contents from temp folder to current directory
shopt -s dotglob
mv "$TEMP_DIR/sgt5_core" ./
rm -rf "$TEMP_DIR"

# Update template.env
TEMPLATE_ENV_PATH="./sgt5_core/templates/template.env"
if [ -f "$TEMPLATE_ENV_PATH" ]; then
    # Remove possible carriage return for compatibility
    sed -i 's/\r$//' "$TEMPLATE_ENV_PATH"

    # Add or update INIT_SGT5_VERSION
    if grep -q "^INIT_SGT5_VERSION=" "$TEMPLATE_ENV_PATH"; then
        sed -i "s/^INIT_SGT5_VERSION=.*/INIT_SGT5_VERSION=$TARGET_VERSION/" "$TEMPLATE_ENV_PATH"
        echo "INIT_SGT5_VERSION updated to $TARGET_VERSION in template.env."
    else
        echo "INIT_SGT5_VERSION=$TARGET_VERSION" >> "$TEMPLATE_ENV_PATH"
        echo "INIT_SGT5_VERSION added to template.env."
    fi
    # Add or update INIT_SGT5_BRANCH
    if grep -q "^INIT_SGT5_BRANCH=" "$TEMPLATE_ENV_PATH"; then
        sed -i "s/^INIT_SGT5_BRANCH=.*/INIT_SGT5_BRANCH=$FALLBACK_BRANCH/" "$TEMPLATE_ENV_PATH"
        echo "INIT_SGT5_BRANCH updated to $FALLBACK_BRANCH in template.env."
    else
        echo "INIT_SGT5_BRANCH=$FALLBACK_BRANCH" >> "$TEMPLATE_ENV_PATH"
        echo "INIT_SGT5_BRANCH added to template.env."
    fi
    # Add or update GITHUB_TOKEN
    if grep -q "^GITHUB_TOKEN=" "$TEMPLATE_ENV_PATH"; then
        sed -i "s/^GITHUB_TOKEN=.*/GITHUB_TOKEN=$GITHUB_TOKEN/" "$TEMPLATE_ENV_PATH"
        echo "GITHUB_TOKEN updated to value in template.env."
    else
        echo "GITHUB_TOKEN=$GITHUB_TOKEN" >> "$TEMPLATE_ENV_PATH"
        echo "GITHUB_TOKEN added to template.env."
    fi
else
    echo "[WARNING] template.env not found at $TEMPLATE_ENV_PATH."
fi

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
