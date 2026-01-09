#!/usr/bin/env bash
set -e

# Configuration (can be overridden via environment variables)
REPO_URL="${REPO_URL:-}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/project}"
BRANCH="${BRANCH:-main}"
NODE_VERSION="${NODE_VERSION:-24}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_os() {
    local os
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        darwin*) echo "darwin" ;;
        linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    elif command_exists apk; then
        echo "apk"
    elif command_exists brew; then
        echo "brew"
    else
        echo "unknown"
    fi
}

install_xcode_clt() {
    log_info "Installing Xcode Command Line Tools..."
    
    # Check if already installed
    if xcode-select -p &>/dev/null; then
        log_info "Xcode Command Line Tools already installed"
        return 0
    fi
    
    # Headless installation via softwareupdate
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    
    local clt_package
    clt_package=$(softwareupdate -l 2>/dev/null | grep -o '.*Command Line Tools.*' | head -n 1 | sed 's/^[* ]*//' | tr -d '\n')
    
    if [ -n "$clt_package" ]; then
        log_info "Installing: $clt_package"
        softwareupdate -i "$clt_package" --verbose
    else
        log_warn "Could not find Command Line Tools package via softwareupdate"
        log_info "Falling back to xcode-select --install (may require GUI interaction)"
        xcode-select --install 2>/dev/null || true
        log_warn "Please complete the installation in the GUI dialog, then re-run this script"
        exit 1
    fi
    
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    log_success "Xcode Command Line Tools installed"
}

ensure_homebrew_in_path() {
    # Ensure Homebrew is in PATH (needed for non-interactive shells)
    if [ -d "/opt/homebrew/bin" ] && [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
        export PATH="/opt/homebrew/bin:$PATH"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -d "/usr/local/bin" ] && [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        export PATH="/usr/local/bin:$PATH"
    fi
}

install_homebrew() {
    # First ensure any existing Homebrew is in PATH
    ensure_homebrew_in_path
    
    if command_exists brew; then
        log_info "Homebrew already installed"
        return 0
    fi
    
    log_info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [ -d "/opt/homebrew/bin" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -d "/usr/local/bin" ]; then
        export PATH="/usr/local/bin:$PATH"
    fi
    
    log_success "Homebrew installed"
}

install_git_linux() {
    local pkg_manager="$1"
    log_info "Installing git via $pkg_manager..."
    
    case "$pkg_manager" in
        apt)
            sudo apt-get update -y
            sudo apt-get install -y git
            ;;
        dnf)
            sudo dnf install -y git
            ;;
        yum)
            sudo yum install -y git
            ;;
        pacman)
            sudo pacman -Sy --noconfirm git
            ;;
        zypper)
            sudo zypper install -y git
            ;;
        apk)
            sudo apk add --no-cache git
            ;;
        *)
            log_error "Unknown package manager: $pkg_manager"
            return 1
            ;;
    esac
    
    log_success "Git installed"
}

install_git_macos() {
    log_info "Installing git on macOS..."
    
    # First ensure Xcode CLT is installed (includes git)
    install_xcode_clt
    
    # Verify git is available
    if command_exists git; then
        log_success "Git is available"
        return 0
    fi
    
    # Fallback: install via Homebrew
    install_homebrew
    brew install git
    log_success "Git installed via Homebrew"
}

ensure_git() {
    if command_exists git; then
        log_info "Git already installed: $(git --version)"
        return 0
    fi
    
    local os
    os=$(detect_os)
    
    if [ "$os" = "darwin" ]; then
        install_git_macos
    elif [ "$os" = "linux" ]; then
        local pkg_manager
        pkg_manager=$(detect_package_manager)
        install_git_linux "$pkg_manager"
    else
        log_error "Unsupported operating system: $os"
        return 1
    fi
}

install_chrome_macos() {
    if [ -d "/Applications/Google Chrome.app" ]; then
        log_info "Google Chrome already installed"
        return 0
    fi
    
    log_info "Installing Google Chrome..."
    brew install --cask google-chrome
    
    # Remove quarantine attribute
    if [ -d "/Applications/Google Chrome.app" ]; then
        xattr -r -d com.apple.quarantine "/Applications/Google Chrome.app" 2>/dev/null || true
    fi
    
    log_success "Google Chrome installed"
}

install_warp_macos() {
    if [ -d "/Applications/Warp.app" ]; then
        log_info "Warp already installed"
        return 0
    fi
    
    log_info "Installing Warp..."
    brew install --cask warp
    
    # Remove quarantine attribute
    if [ -d "/Applications/Warp.app" ]; then
        xattr -r -d com.apple.quarantine "/Applications/Warp.app" 2>/dev/null || true
    fi
    
    log_success "Warp installed"
}

install_nvm() {
    export NVM_DIR="$HOME/.nvm"
    
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        log_info "nvm already installed"
        source "$NVM_DIR/nvm.sh"
        return 0
    fi
    
    log_info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    
    # Load nvm
    source "$NVM_DIR/nvm.sh"
    
    log_success "nvm installed"
}

install_node() {
    log_info "Installing Node.js $NODE_VERSION..."
    
    # Ensure nvm is loaded
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
    
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    
    log_success "Node.js $(node --version) installed"
}

configure_dock_macos() {
    log_info "Configuring Dock..."
    
    # Clear all apps from dock
    defaults write com.apple.dock persistent-apps -array
    
    # Add Chrome
    if [ -d "/Applications/Google Chrome.app" ]; then
        defaults write com.apple.dock persistent-apps -array-add \
            "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Google Chrome.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    fi
    
    # Add Warp
    if [ -d "/Applications/Warp.app" ]; then
        defaults write com.apple.dock persistent-apps -array-add \
            "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Warp.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    fi
    
    # Add System Settings (macOS Ventura+) or System Preferences
    if [ -d "/System/Applications/System Settings.app" ]; then
        defaults write com.apple.dock persistent-apps -array-add \
            "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/System/Applications/System Settings.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    elif [ -d "/Applications/System Preferences.app" ]; then
        defaults write com.apple.dock persistent-apps -array-add \
            "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/System Preferences.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    fi
    
    # Disable recent applications in dock
    defaults write com.apple.dock show-recents -bool false
    
    # Restart dock to apply changes
    killall Dock
    
    log_success "Dock configured"
}

install_docker_linux() {
    log_info "Installing Docker on Linux..."
    
    # Use official Docker convenience script
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
    
    # Add current user to docker group
    if [ -n "$SUDO_USER" ]; then
        sudo usermod -aG docker "$SUDO_USER"
        log_info "Added $SUDO_USER to docker group"
    elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
        sudo usermod -aG docker "$USER"
        log_info "Added $USER to docker group"
    fi
    
    # Start and enable docker service
    if command_exists systemctl; then
        sudo systemctl start docker 2>/dev/null || true
        sudo systemctl enable docker 2>/dev/null || true
    fi
    
    log_success "Docker installed"
    log_warn "You may need to log out and back in for docker group changes to take effect"
}

install_docker_macos() {
    if [ -d "/Applications/Docker.app" ]; then
        log_info "Docker Desktop already installed"
    else
        log_info "Installing Docker Desktop on macOS..."
        brew install --cask docker
        
        # Remove quarantine attribute for headless operation
        if [ -d "/Applications/Docker.app" ]; then
            xattr -r -d com.apple.quarantine /Applications/Docker.app 2>/dev/null || true
        fi
        
        log_success "Docker Desktop installed"
    fi
    
    # Start Docker Desktop
    log_info "Starting Docker Desktop..."
    open -a Docker
    
    # Wait for Docker to be ready
    log_info "Waiting for Docker to start..."
    local max_attempts=30
    local attempt=0
    while ! docker info &>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            log_warn "Docker took too long to start. It may still be initializing."
            return 0
        fi
        sleep 2
    done
    
    log_success "Docker is running"
}

prompt_repo_url() {
    if [ -z "$REPO_URL" ]; then
        echo ""
        read -p "Enter repository URL (or press Enter to skip): " REPO_URL
        if [ -z "$REPO_URL" ]; then
            log_info "No repository URL provided, skipping clone"
        fi
    fi
}

clone_repository() {
    if [ -z "$REPO_URL" ]; then
        return 0
    fi
    
    log_info "Cloning repository: $REPO_URL"
    
    if [ -d "$INSTALL_DIR" ]; then
        log_warn "Directory $INSTALL_DIR already exists"
        if [ -d "$INSTALL_DIR/.git" ]; then
            log_info "Pulling latest changes..."
            cd "$INSTALL_DIR"
            git fetch origin
            git checkout "$BRANCH"
            git pull origin "$BRANCH"
            return 0
        else
            log_error "Directory exists but is not a git repository"
            return 1
        fi
    fi
    
    git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    log_success "Repository cloned to $INSTALL_DIR"
}

run_install_script() {
    if [ -z "$REPO_URL" ]; then
        return 0
    fi
    
    local install_script="$INSTALL_DIR/scripts/install.sh"
    
    if [ -f "$install_script" ]; then
        log_info "Running install script: $install_script"
        chmod +x "$install_script"
        cd "$INSTALL_DIR"
        "$install_script"
        log_success "Install script completed"
    else
        log_info "No install script found at $install_script"
    fi
}

main() {
    echo ""
    echo "=========================================="
    echo "  Startup Bootstrap Script"
    echo "=========================================="
    echo ""
    
    local os
    os=$(detect_os)
    log_info "Detected OS: $os"
    
    if [ "$os" = "unknown" ]; then
        log_error "Unsupported operating system"
        exit 1
    fi
    
    if [ "$os" = "darwin" ]; then
        # macOS setup
        install_xcode_clt
        install_homebrew
        ensure_git
        install_chrome_macos
        install_warp_macos
        install_nvm
        install_node
        install_docker_macos
        configure_dock_macos
    elif [ "$os" = "linux" ]; then
        # Linux setup
        local pkg_manager
        pkg_manager=$(detect_package_manager)
        log_info "Detected package manager: $pkg_manager"
        ensure_git
        install_nvm
        install_node
        install_docker_linux
    fi
    
    # Prompt for repository URL if not provided
    prompt_repo_url
    
    # Clone repository
    clone_repository
    
    # Run install script if exists
    run_install_script
    
    echo ""
    log_success "Bootstrap completed!"
    echo ""
}

main "$@"
