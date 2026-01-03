#!/usr/bin/env bash
#
# setup-yubikey-sudo.sh
#
# Configure Ubuntu 24.04 (Noble) to use a YubiKey as the sudo authenticator
# via the pam_u2f module. Supports both interactive and fully automated usage.
#
# Author: Automation Engineer
# License: MIT
# Version: 1.0.0
#
# Usage:
#   Interactive:
#     sudo ./setup-yubikey-sudo.sh
#     sudo ./setup-yubikey-sudo.sh passwordless
#     sudo ./setup-yubikey-sudo.sh 2fa
#
#   Automated:
#     sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
#     sudo ./setup-yubikey-sudo.sh --mode 2fa --no-cue --user alice --yes
#     sudo ./setup-yubikey-sudo.sh --mode passwordless --authfile /custom/path --yes
#
# Safety features:
#   - Automatic backup of /etc/pam.d/sudo before modification
#   - Graceful handling of existing pam_u2f.so entries
#   - Clear rollback instructions
#   - Comprehensive error checking
#

set -euo pipefail

################################################################################
# Constants and Defaults
################################################################################

readonly SCRIPT_VERSION="1.0.0"
readonly PAM_SUDO_FILE="/etc/pam.d/sudo"
readonly DEFAULT_AUTHFILE="/etc/u2f_mappings"
readonly REQUIRED_PACKAGES=("libpam-u2f" "pamu2fcfg")

# Color codes for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

################################################################################
# Global Variables (set by argument parsing)
################################################################################

MODE="passwordless"           # passwordless or 2fa
ENABLE_CUE=true              # Enable cue prompt by default
TARGET_USER=""               # Auto-detect if empty
AUTHFILE="$DEFAULT_AUTHFILE" # Mapping file path
ASSUME_YES=false             # Skip confirmations
NO_INSTALL=false             # Skip package installation
DRY_RUN=false                # Print actions without applying (future extension)
INTERACTIVE=true             # Set to false when using automation flags

################################################################################
# Helper Functions
################################################################################

# Print colored output
print_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

print_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

print_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

print_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# Print usage information
print_usage() {
    cat << 'EOF'
Usage: setup-yubikey-sudo.sh [OPTIONS] [MODE]

Configure Ubuntu 24.04 to use YubiKey for sudo authentication via pam_u2f.

MODES:
  passwordless    YubiKey alone grants sudo access (default)
  2fa             Password + YubiKey (two-factor authentication)

OPTIONS:
  --mode MODE           Set authentication mode (passwordless|2fa)
  --cue                 Enable touch prompt (default)
  --no-cue              Disable touch prompt
  --user USERNAME       Specify user to enroll (default: auto-detect)
  --authfile PATH       Mapping file path (default: /etc/u2f_mappings)
  --yes, --assume-yes   Skip interactive confirmations
  --no-install          Skip automatic package installation
  -h, --help            Show this help message

EXAMPLES:
  Interactive usage:
    sudo ./setup-yubikey-sudo.sh
    sudo ./setup-yubikey-sudo.sh passwordless
    sudo ./setup-yubikey-sudo.sh 2fa

  Automated usage:
    sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
    sudo ./setup-yubikey-sudo.sh --mode 2fa --no-cue --user alice --yes
    sudo ./setup-yubikey-sudo.sh --mode passwordless --authfile /custom/path --yes

SAFETY:
  - Automatic backup of /etc/pam.d/sudo before modification
  - Backup location: /etc/pam.d/sudo.bak.<timestamp>
  - To rollback: sudo cp /etc/pam.d/sudo.bak.<timestamp> /etc/pam.d/sudo

TESTING:
  After setup, test in a NEW terminal:
    sudo -k
    sudo echo SUCCESS
  
  You should see the YubiKey prompt (if cue enabled) and need to touch the device.

EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect the actual user who invoked sudo
detect_actual_user() {
    local user=""
    
    # Try SUDO_USER first (most reliable when using sudo)
    if [[ -n "${SUDO_USER:-}" ]]; then
        user="$SUDO_USER"
    # Fallback to logname
    elif user=$(logname 2>/dev/null); then
        :
    # Last resort: check who owns the terminal
    elif [[ -t 0 ]]; then
        user=$(stat -c '%U' /proc/self/fd/0 2>/dev/null || echo "")
    fi
    
    # Validate user exists
    if [[ -z "$user" ]] || ! id "$user" &>/dev/null; then
        print_error "Could not detect actual user. Please specify with --user USERNAME"
        exit 1
    fi
    
    echo "$user"
}

# Check if a package is installed
is_package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q '^ii'
}

# Enable Universe repository if not already enabled
enable_universe() {
    if ! grep -q "^deb.*universe" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        print_info "Enabling Universe repository..."
        if command -v add-apt-repository &>/dev/null; then
            add-apt-repository -y universe
        else
            # Fallback: manually add universe to sources
            sed -i 's/^deb \(.*\) noble main$/deb \1 noble main universe/' /etc/apt/sources.list
        fi
        apt-get update -qq
    fi
}

# Install required packages
install_packages() {
    if [[ "$NO_INSTALL" == true ]]; then
        print_info "Package installation skipped (--no-install specified)"
        # Check if required packages are available
        for pkg in "${REQUIRED_PACKAGES[@]}"; do
            if ! is_package_installed "$pkg"; then
                print_error "Required package '$pkg' is not installed and --no-install was specified"
                exit 1
            fi
        done
        return
    fi
    
    local packages_to_install=()
    
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! is_package_installed "$pkg"; then
            packages_to_install+=("$pkg")
        fi
    done
    
    if [[ ${#packages_to_install[@]} -eq 0 ]]; then
        print_info "All required packages are already installed"
        return
    fi
    
    print_info "Installing required packages: ${packages_to_install[*]}"
    
    # Enable Universe if needed
    enable_universe
    
    # Update package list and install
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages_to_install[@]}"
    
    print_success "Packages installed successfully"
}

# Confirm action with user (unless --yes is set)
confirm_action() {
    local prompt="$1"
    
    if [[ "$ASSUME_YES" == true ]]; then
        return 0
    fi
    
    echo -e "${COLOR_YELLOW}${prompt}${COLOR_RESET}"
    read -r -p "Continue? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            print_info "Operation cancelled by user"
            exit 0
            ;;
    esac
}

# Backup PAM sudo file
backup_pam_file() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${PAM_SUDO_FILE}.bak.${timestamp}"
    
    if [[ ! -f "$PAM_SUDO_FILE" ]]; then
        print_error "PAM sudo file not found: $PAM_SUDO_FILE"
        exit 1
    fi
    
    cp -a "$PAM_SUDO_FILE" "$backup_file"
    print_success "Backed up PAM file to: $backup_file"
    echo "$backup_file"
}

# Get hostname for origin string
get_hostname() {
    hostname -f 2>/dev/null || hostname
}

# Build PAM line based on configuration
build_pam_line() {
    local auth_control
    local pam_options=()
    
    # Determine auth control (sufficient for passwordless, required for 2fa)
    if [[ "$MODE" == "passwordless" ]]; then
        auth_control="sufficient"
    else
        auth_control="required"
    fi
    
    # Add cue option if enabled
    if [[ "$ENABLE_CUE" == true ]]; then
        pam_options+=("cue")
    fi
    
    # Add authfile
    pam_options+=("authfile=${AUTHFILE}")
    
    # Add origin
    local origin="pam://$(get_hostname)"
    pam_options+=("origin=${origin}")
    
    # Build the complete line with proper spacing
    local options_str
    options_str=$(IFS=$'\t'; echo "${pam_options[*]}")
    
    echo "auth\tsufficient\tpam_u2f.so\t${options_str}" | sed "s/sufficient/${auth_control}/"
}

# Update PAM configuration
update_pam_config() {
    local backup_file
    backup_file=$(backup_pam_file)
    
    local new_pam_line
    new_pam_line=$(build_pam_line)
    
    # Create temporary file for safe editing
    local temp_file
    temp_file=$(mktemp)
    
    # Check if pam_u2f.so already exists in the file
    if grep -q "pam_u2f.so" "$PAM_SUDO_FILE"; then
        print_info "Existing pam_u2f.so entry found, updating..."
        
        # Replace existing pam_u2f.so line
        sed "s|^auth.*pam_u2f\.so.*|${new_pam_line}|" "$PAM_SUDO_FILE" > "$temp_file"
    else
        print_info "Adding new pam_u2f.so entry..."
        
        # Insert before first @include common-auth or at the beginning of auth section
        if grep -q "@include common-auth" "$PAM_SUDO_FILE"; then
            # Insert before first @include common-auth
            awk -v line="$new_pam_line" '
                !inserted && /@include common-auth/ {
                    print line
                    inserted=1
                }
                { print }
            ' "$PAM_SUDO_FILE" > "$temp_file"
        else
            # Fallback: insert after the first auth line or at the top
            awk -v line="$new_pam_line" '
                BEGIN { inserted=0 }
                /^auth/ && !inserted {
                    print line
                    inserted=1
                }
                { print }
                END {
                    if (!inserted) {
                        print line
                    }
                }
            ' "$PAM_SUDO_FILE" > "$temp_file"
        fi
    fi
    
    # Validate the temporary file is not empty
    if [[ ! -s "$temp_file" ]]; then
        print_error "Generated PAM configuration is empty. Aborting."
        rm -f "$temp_file"
        exit 1
    fi
    
    # Move temporary file to actual location
    mv "$temp_file" "$PAM_SUDO_FILE"
    chmod 644 "$PAM_SUDO_FILE"
    
    print_success "PAM configuration updated successfully"
    print_info "Backup available at: $backup_file"
}

# Register YubiKey for user
register_yubikey() {
    local user="$1"
    local origin="pam://$(get_hostname)"
    
    print_info "Registering YubiKey for user: $user"
    print_info "Origin: $origin"
    echo ""
    
    if [[ "$INTERACTIVE" == true ]]; then
        print_warning "Please insert your YubiKey and prepare to touch it when prompted."
        print_info "You may be asked to enter a PIN if your YubiKey requires one."
        echo ""
        read -r -p "Press Enter when ready..."
        echo ""
    fi
    
    # Run pamu2fcfg as the target user
    local mapping_line
    print_info "Touch your YubiKey now..."
    
    if ! mapping_line=$(su - "$user" -c "pamu2fcfg -o${origin} -i${origin}" 2>&1); then
        print_error "Failed to register YubiKey"
        print_error "Output: $mapping_line"
        exit 1
    fi
    
    # Validate mapping line format (should be: username:keyHandle,publicKey)
    if [[ ! "$mapping_line" =~ ^[^:]+:.+ ]]; then
        print_error "Invalid mapping format received from pamu2fcfg"
        print_error "Output: $mapping_line"
        exit 1
    fi
    
    print_success "YubiKey registered successfully"
    
    # Ensure authfile directory exists
    local authfile_dir
    authfile_dir=$(dirname "$AUTHFILE")
    mkdir -p "$authfile_dir"
    
    # Check if user already has an entry in the authfile
    if [[ -f "$AUTHFILE" ]] && grep -q "^${user}:" "$AUTHFILE"; then
        print_info "Updating existing entry for user $user in $AUTHFILE"
        # Remove old entry and add new one
        grep -v "^${user}:" "$AUTHFILE" > "${AUTHFILE}.tmp" || true
        echo "$mapping_line" >> "${AUTHFILE}.tmp"
        mv "${AUTHFILE}.tmp" "$AUTHFILE"
    else
        print_info "Adding new entry for user $user to $AUTHFILE"
        echo "$mapping_line" >> "$AUTHFILE"
    fi
    
    # Set proper permissions (readable by root and PAM)
    chmod 640 "$AUTHFILE"
    chown root:root "$AUTHFILE"
    
    print_success "Mapping saved to: $AUTHFILE"
}

# Display configuration summary
display_summary() {
    echo ""
    echo "========================================================================"
    echo "                    YubiKey Sudo Setup Complete"
    echo "========================================================================"
    echo ""
    echo "Configuration Summary:"
    echo "  Mode:           $MODE"
    echo "  Cue Prompt:     $(if [[ "$ENABLE_CUE" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
    echo "  User:           $TARGET_USER"
    echo "  Mapping File:   $AUTHFILE"
    echo "  Origin:         pam://$(get_hostname)"
    echo ""
    echo "========================================================================"
    echo ""
    
    print_warning "IMPORTANT: Test sudo in a NEW terminal before closing this session!"
    echo ""
    echo "Test steps:"
    echo "  1. Open a new terminal"
    echo "  2. Run: sudo -k"
    echo "  3. Run: sudo echo SUCCESS"
    echo ""
    
    if [[ "$ENABLE_CUE" == true ]]; then
        echo "Expected behavior:"
        echo "  - You should see: 'Please touch the device.'"
        echo "  - Touch your YubiKey to authenticate"
    else
        echo "Expected behavior:"
        echo "  - Your YubiKey LED should blink (no text prompt)"
        echo "  - Touch your YubiKey to authenticate"
    fi
    
    if [[ "$MODE" == "2fa" ]]; then
        echo "  - You will also need to enter your password"
    fi
    
    echo ""
    print_warning "If you get locked out, you can rollback using:"
    echo "  Boot into recovery mode or use another sudo-capable session"
    echo "  Restore from backup: sudo cp ${PAM_SUDO_FILE}.bak.* ${PAM_SUDO_FILE}"
    echo ""
    echo "========================================================================"
    echo ""
}

################################################################################
# Argument Parsing
################################################################################

parse_arguments() {
    # If no arguments, use interactive mode with defaults
    if [[ $# -eq 0 ]]; then
        INTERACTIVE=true
        return
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                print_usage
                exit 0
                ;;
            --mode)
                if [[ -z "${2:-}" ]]; then
                    print_error "Option --mode requires an argument"
                    exit 1
                fi
                MODE="$2"
                INTERACTIVE=false
                shift 2
                ;;
            --cue)
                ENABLE_CUE=true
                INTERACTIVE=false
                shift
                ;;
            --no-cue)
                ENABLE_CUE=false
                INTERACTIVE=false
                shift
                ;;
            --user)
                if [[ -z "${2:-}" ]]; then
                    print_error "Option --user requires an argument"
                    exit 1
                fi
                TARGET_USER="$2"
                INTERACTIVE=false
                shift 2
                ;;
            --authfile)
                if [[ -z "${2:-}" ]]; then
                    print_error "Option --authfile requires an argument"
                    exit 1
                fi
                AUTHFILE="$2"
                INTERACTIVE=false
                shift 2
                ;;
            --yes|--assume-yes)
                ASSUME_YES=true
                INTERACTIVE=false
                shift
                ;;
            --no-install)
                NO_INSTALL=true
                shift
                ;;
            passwordless|2fa)
                # Legacy positional argument support
                MODE="$1"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Validate mode
    if [[ "$MODE" != "passwordless" && "$MODE" != "2fa" ]]; then
        print_error "Invalid mode: $MODE (must be 'passwordless' or '2fa')"
        exit 1
    fi
}

################################################################################
# Interactive Mode Functions
################################################################################

interactive_mode() {
    echo ""
    echo "========================================================================"
    echo "           YubiKey Sudo Setup - Interactive Mode"
    echo "========================================================================"
    echo ""
    echo "This script will configure your system to use a YubiKey for sudo"
    echo "authentication via the pam_u2f module."
    echo ""
    
    # Ask for mode if not already set via positional argument
    if [[ "$MODE" == "passwordless" ]] && [[ $# -eq 0 ]]; then
        echo "Select authentication mode:"
        echo "  1) Passwordless - YubiKey alone grants sudo access (recommended)"
        echo "  2) Two-Factor (2FA) - Password + YubiKey required"
        echo ""
        read -r -p "Enter choice [1-2] (default: 1): " mode_choice
        
        case "$mode_choice" in
            2)
                MODE="2fa"
                ;;
            1|"")
                MODE="passwordless"
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
    fi
    
    # Ask about cue prompt
    echo ""
    read -r -p "Enable touch prompt (shows 'Please touch the device')? [Y/n]: " cue_choice
    case "$cue_choice" in
        [nN][oO]|[nN])
            ENABLE_CUE=false
            ;;
        *)
            ENABLE_CUE=true
            ;;
    esac
    
    echo ""
    echo "Configuration:"
    echo "  Mode: $MODE"
    echo "  Cue Prompt: $(if [[ "$ENABLE_CUE" == true ]]; then echo "Enabled"; else echo "Disabled"; fi)"
    echo "  User: $TARGET_USER"
    echo "  Mapping File: $AUTHFILE"
    echo ""
    
    confirm_action "This will modify /etc/pam.d/sudo and may affect your ability to use sudo."
}

################################################################################
# Main Function
################################################################################

main() {
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Check root privileges
    check_root
    
    # Detect target user if not specified
    if [[ -z "$TARGET_USER" ]]; then
        TARGET_USER=$(detect_actual_user)
        print_info "Detected user: $TARGET_USER"
    fi
    
    # Validate target user exists
    if ! id "$TARGET_USER" &>/dev/null; then
        print_error "User does not exist: $TARGET_USER"
        exit 1
    fi
    
    # Run interactive prompts if in interactive mode
    if [[ "$INTERACTIVE" == true ]]; then
        interactive_mode "$@"
    fi
    
    # Install required packages
    install_packages
    
    # Confirm before making changes (unless --yes)
    if [[ "$INTERACTIVE" == false ]] && [[ "$ASSUME_YES" == false ]]; then
        confirm_action "Proceed with YubiKey sudo setup for user $TARGET_USER in $MODE mode?"
    fi
    
    # Register YubiKey
    register_yubikey "$TARGET_USER"
    
    # Update PAM configuration
    update_pam_config
    
    # Display summary and testing instructions
    display_summary
    
    print_success "Setup completed successfully!"
}

################################################################################
# Script Entry Point
################################################################################

# Trap errors and provide helpful message
trap 'print_error "Script failed at line $LINENO. Check the error message above."' ERR

# Run main function with all arguments
main "$@"
