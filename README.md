# YubiKey Sudo Setup Script

A robust, production-ready Bash script for configuring Ubuntu 24.04 (Noble) to use YubiKey as the sudo authenticator via the pam_u2f module.

## Features

✅ **Dual Operation Modes**
- Interactive mode with guided prompts
- Fully automated mode for scripting and CI/CD

✅ **Authentication Modes**
- **Passwordless**: YubiKey alone grants sudo access
- **2FA**: Password + YubiKey (two-factor authentication)

✅ **Safety First**
- Automatic backup of PAM configuration with timestamps
- Graceful handling of existing configurations
- Clear rollback instructions
- Comprehensive error checking

✅ **Flexible Configuration**
- Customizable touch prompt (cue)
- Custom mapping file paths
- Per-user enrollment
- Package installation control

✅ **Production Ready**
- Idempotent operations
- Proper file permissions (640 for mappings, 644 for PAM)
- Atomic file operations
- Comprehensive logging and error messages

## Quick Start

### Interactive Mode

```bash
sudo ./setup-yubikey-sudo.sh
```

Follow the prompts to configure your YubiKey for sudo authentication.

### Automated Mode

```bash
# Passwordless with touch prompt
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Two-factor authentication
sudo ./setup-yubikey-sudo.sh --mode 2fa --yes

# Passwordless without touch prompt
sudo ./setup-yubikey-sudo.sh --mode passwordless --no-cue --yes
```

## Requirements

- Ubuntu 24.04 (Noble Numbat)
- YubiKey with FIDO2/U2F support
- Root/sudo privileges
- Packages: `libpam-u2f`, `pamu2fcfg` (auto-installed)

## Installation

```bash
# Download the script
wget https://example.com/setup-yubikey-sudo.sh

# Make executable
chmod +x setup-yubikey-sudo.sh

# Run with sudo
sudo ./setup-yubikey-sudo.sh
```

## Usage

### Command-Line Options

```
Usage: setup-yubikey-sudo.sh [OPTIONS] [MODE]

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
```

### Examples

**Interactive with defaults:**
```bash
sudo ./setup-yubikey-sudo.sh
```

**Legacy positional arguments:**
```bash
sudo ./setup-yubikey-sudo.sh passwordless
sudo ./setup-yubikey-sudo.sh 2fa
```

**Automated deployment:**
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
```

**Custom configuration:**
```bash
sudo ./setup-yubikey-sudo.sh \
  --mode 2fa \
  --no-cue \
  --user alice \
  --authfile /custom/path/mappings \
  --yes
```

**Skip package installation:**
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --no-install --yes
```

## Testing Your Setup

**CRITICAL:** Always test in a NEW terminal before closing your current session!

```bash
# Open a new terminal
# Clear sudo credentials
sudo -k

# Test sudo with YubiKey
sudo echo SUCCESS
```

### Expected Behavior

**Passwordless with cue:**
- Prompt: "Please touch the device."
- Touch YubiKey → Success (no password)

**Passwordless without cue:**
- YubiKey LED blinks (no text)
- Touch YubiKey → Success (no password)

**2FA with cue:**
- Prompt: "Please touch the device."
- Touch YubiKey → Password prompt → Success

**2FA without cue:**
- YubiKey LED blinks
- Touch YubiKey → Password prompt → Success

## Rollback / Recovery

If you get locked out of sudo:

### Method 1: Another Terminal
```bash
# Find the backup
ls -lt /etc/pam.d/sudo.bak.*

# Restore (use most recent timestamp)
sudo cp /etc/pam.d/sudo.bak.20260103_120000 /etc/pam.d/sudo
```

### Method 2: Recovery Mode
1. Reboot and hold Shift to enter GRUB menu
2. Select "Advanced options" → "Recovery mode"
3. Select "Drop to root shell prompt"
4. Remount filesystem: `mount -o remount,rw /`
5. Restore backup: `cp /etc/pam.d/sudo.bak.* /etc/pam.d/sudo`
6. Reboot: `reboot`

### Method 3: Live USB
1. Boot from Ubuntu Live USB
2. Mount your system partition
3. Restore the backup file
4. Reboot

## File Locations

| File | Purpose | Permissions |
|------|---------|-------------|
| `/etc/pam.d/sudo` | PAM configuration for sudo | `644` (root:root) |
| `/etc/pam.d/sudo.bak.*` | Timestamped backups | `644` (root:root) |
| `/etc/u2f_mappings` | YubiKey mappings (default) | `640` (root:root) |
| `/var/log/auth.log` | Authentication logs | `640` (syslog:adm) |

## PAM Configuration

### Passwordless Mode
```
auth    sufficient    pam_u2f.so    cue    authfile=/etc/u2f_mappings    origin=pam://hostname
```
- `sufficient`: Success allows immediate authentication
- Falls back to password if YubiKey fails

### 2FA Mode
```
auth    required      pam_u2f.so    cue    authfile=/etc/u2f_mappings    origin=pam://hostname
```
- `required`: Must succeed for authentication
- Used in addition to password authentication

## Automation Examples

### Ansible Playbook
```yaml
- name: Configure YubiKey sudo
  hosts: workstations
  become: yes
  tasks:
    - name: Run YubiKey setup
      command: >
        /path/to/setup-yubikey-sudo.sh
        --mode passwordless
        --yes
```

### Shell Script
```bash
#!/bin/bash
for user in alice bob charlie; do
    sudo ./setup-yubikey-sudo.sh \
        --mode passwordless \
        --user "$user" \
        --yes
done
```

## Security Considerations

### Best Practices
- ✅ Test in a VM before production deployment
- ✅ Keep multiple backups of PAM configuration
- ✅ Register a backup YubiKey for each user
- ✅ Monitor `/var/log/auth.log` for failed attempts
- ✅ Use 2FA mode for high-security environments

### Physical Security
- 🔑 YubiKey must be physically present for sudo
- 🔑 Lost YubiKey requires recovery mode access
- 🔑 Consider keeping backup YubiKey in secure location

### Multi-User Environments
- Each user needs their own YubiKey registration
- Mapping file contains all user mappings
- File permissions prevent unauthorized access

## Troubleshooting

### "Could not detect actual user"
**Solution:** Specify user explicitly:
```bash
sudo ./setup-yubikey-sudo.sh --user alice --yes
```

### "Required package not installed" with --no-install
**Solution:** Install packages manually:
```bash
sudo apt-get update
sudo apt-get install -y libpam-u2f pamu2fcfg
```

### YubiKey not detected
**Checklist:**
- ✓ YubiKey is inserted
- ✓ YubiKey LED is on
- ✓ Try different USB port
- ✓ Check `lsusb` for Yubico device

### "Please touch the device" but nothing happens
**Possible causes:**
- YubiKey requires PIN (enter when prompted)
- YubiKey not in FIDO2 mode
- USB connection issue

## Advanced Usage

### Multiple YubiKeys per User
```bash
# Register first YubiKey
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Manually append second YubiKey
sudo su - $USER -c "pamu2fcfg -opam://$(hostname) -ipam://$(hostname)" | \
  sudo tee -a /etc/u2f_mappings
```

### Custom Origin String
The script uses `pam://HOSTNAME` by default. To customize, edit the `get_hostname()` function in the script.

### Per-User Mapping Files
```bash
# Create user directory
sudo mkdir -p /home/alice/.config/Yubico
sudo chown alice:alice /home/alice/.config/Yubico

# Use custom authfile
sudo ./setup-yubikey-sudo.sh \
  --user alice \
  --authfile /home/alice/.config/Yubico/u2f_keys \
  --yes
```

## Documentation

- **USAGE_EXAMPLES.md**: Comprehensive usage examples and scenarios
- **TEST_SCENARIOS.md**: Complete test suite with 30+ test cases
- **README.md**: This file

## Version History

- **1.0.0** (2026-01-03): Initial release
  - Interactive and automated modes
  - Passwordless and 2FA support
  - Cue prompt configuration
  - Automatic package installation
  - Safe PAM file editing with backups

## License

MIT License

## Support

For issues or questions:
1. Check `/var/log/auth.log` for authentication errors
2. Review PAM backup files in `/etc/pam.d/`
3. Test in a safe environment before production deployment

## Contributing

Contributions welcome! Please ensure:
- All tests pass (see TEST_SCENARIOS.md)
- Code follows existing style
- Documentation is updated
- Security implications are considered

## Acknowledgments

- Built for Ubuntu 24.04 (Noble Numbat)
- Uses Yubico's pam_u2f module
- Follows PAM best practices
- Designed for automation engineers

---

**⚠️ WARNING:** Misconfiguration can lock you out of sudo. Always test in a new terminal and keep a recovery method available.

**✅ RECOMMENDATION:** Test in a VM first, keep backups, and have a recovery plan.
