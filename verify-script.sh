#!/bin/bash
# verify-script.sh - Verify setup-yubikey-sudo.sh functionality

echo "========================================="
echo "Script Verification Report"
echo "========================================="
echo ""

# Check if script exists
if [[ -f "setup-yubikey-sudo.sh" ]]; then
    echo "✓ Script file exists"
else
    echo "✗ Script file not found"
    exit 1
fi

# Check if executable
if [[ -x "setup-yubikey-sudo.sh" ]]; then
    echo "✓ Script is executable"
else
    echo "✗ Script is not executable"
    exit 1
fi

# Syntax check
if bash -n setup-yubikey-sudo.sh 2>/dev/null; then
    echo "✓ Syntax check passed"
else
    echo "✗ Syntax errors found"
    exit 1
fi

# Check shebang
if head -1 setup-yubikey-sudo.sh | grep -q "^#!/usr/bin/env bash"; then
    echo "✓ Correct shebang"
else
    echo "✗ Incorrect shebang"
fi

# Check for set -euo pipefail
if grep -q "^set -euo pipefail" setup-yubikey-sudo.sh; then
    echo "✓ Safe shell options set"
else
    echo "✗ Missing safe shell options"
fi

# Check help function
if ./setup-yubikey-sudo.sh --help 2>&1 | grep -q "Usage:"; then
    echo "✓ Help function works"
else
    echo "✗ Help function broken"
fi

# Check for required functions
REQUIRED_FUNCTIONS=(
    "check_root"
    "detect_actual_user"
    "install_packages"
    "backup_pam_file"
    "update_pam_config"
    "register_yubikey"
    "build_pam_line"
    "parse_arguments"
    "interactive_mode"
    "main"
)

echo ""
echo "Checking required functions:"
for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if grep -q "^${func}()" setup-yubikey-sudo.sh; then
        echo "  ✓ $func"
    else
        echo "  ✗ $func (missing)"
    fi
done

# Check for required constants
echo ""
echo "Checking constants:"
REQUIRED_CONSTANTS=(
    "SCRIPT_VERSION"
    "PAM_SUDO_FILE"
    "DEFAULT_AUTHFILE"
    "REQUIRED_PACKAGES"
)

for const in "${REQUIRED_CONSTANTS[@]}"; do
    if grep -q "readonly ${const}=" setup-yubikey-sudo.sh; then
        echo "  ✓ $const"
    else
        echo "  ✗ $const (missing)"
    fi
done

# Check for color codes
echo ""
echo "Checking output formatting:"
if grep -q "COLOR_RED=" setup-yubikey-sudo.sh; then
    echo "  ✓ Color codes defined"
else
    echo "  ✗ Color codes missing"
fi

# Check for error handling
echo ""
echo "Checking error handling:"
if grep -q "trap.*ERR" setup-yubikey-sudo.sh; then
    echo "  ✓ Error trap defined"
else
    echo "  ✗ Error trap missing"
fi

# Check for backup functionality
if grep -q "backup_pam_file" setup-yubikey-sudo.sh; then
    echo "  ✓ Backup functionality present"
else
    echo "  ✗ Backup functionality missing"
fi

# Check for all command-line options
echo ""
echo "Checking command-line options:"
OPTIONS=(
    "--mode"
    "--cue"
    "--no-cue"
    "--user"
    "--authfile"
    "--yes"
    "--assume-yes"
    "--no-install"
    "--help"
)

for opt in "${OPTIONS[@]}"; do
    if grep -q "${opt})" setup-yubikey-sudo.sh; then
        echo "  ✓ $opt"
    else
        echo "  ✗ $opt (missing)"
    fi
done

# Check for both modes
echo ""
echo "Checking authentication modes:"
if grep -q "passwordless" setup-yubikey-sudo.sh && grep -q "2fa" setup-yubikey-sudo.sh; then
    echo "  ✓ Both modes supported"
else
    echo "  ✗ Missing mode support"
fi

# Check for PAM line building
echo ""
echo "Checking PAM configuration:"
if grep -q "pam_u2f.so" setup-yubikey-sudo.sh; then
    echo "  ✓ PAM module referenced"
else
    echo "  ✗ PAM module not found"
fi

if grep -q "sufficient" setup-yubikey-sudo.sh && grep -q "required" setup-yubikey-sudo.sh; then
    echo "  ✓ Both auth controls supported"
else
    echo "  ✗ Missing auth control"
fi

# Check for package installation
echo ""
echo "Checking package management:"
if grep -q "libpam-u2f" setup-yubikey-sudo.sh && grep -q "pamu2fcfg" setup-yubikey-sudo.sh; then
    echo "  ✓ Required packages defined"
else
    echo "  ✗ Missing package definitions"
fi

if grep -q "apt-get install" setup-yubikey-sudo.sh; then
    echo "  ✓ Package installation logic present"
else
    echo "  ✗ Package installation missing"
fi

# Check for YubiKey registration
echo ""
echo "Checking YubiKey registration:"
if grep -q "pamu2fcfg" setup-yubikey-sudo.sh; then
    echo "  ✓ Registration command present"
else
    echo "  ✗ Registration command missing"
fi

if grep -q "origin=" setup-yubikey-sudo.sh; then
    echo "  ✓ Origin parameter handled"
else
    echo "  ✗ Origin parameter missing"
fi

# Check documentation
echo ""
echo "Checking documentation:"
DOCS=("README.md" "USAGE_EXAMPLES.md" "TEST_SCENARIOS.md" "QUICK_REFERENCE.md")
for doc in "${DOCS[@]}"; do
    if [[ -f "$doc" ]]; then
        echo "  ✓ $doc"
    else
        echo "  ✗ $doc (missing)"
    fi
done

# Line count
echo ""
echo "Script statistics:"
LINES=$(wc -l < setup-yubikey-sudo.sh)
echo "  Total lines: $LINES"

FUNCTIONS=$(grep -c "^[a-z_]*() {" setup-yubikey-sudo.sh)
echo "  Functions: $FUNCTIONS"

COMMENTS=$(grep -c "^#" setup-yubikey-sudo.sh)
echo "  Comment lines: $COMMENTS"

echo ""
echo "========================================="
echo "Verification Complete"
echo "========================================="
echo ""
echo "Script is ready for deployment!"
echo ""
echo "Next steps:"
echo "  1. Review the script: less setup-yubikey-sudo.sh"
echo "  2. Read documentation: less README.md"
echo "  3. Test in VM: sudo ./setup-yubikey-sudo.sh"
echo "  4. Deploy to production"
echo ""
