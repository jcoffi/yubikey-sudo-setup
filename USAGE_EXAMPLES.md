# YubiKey Sudo Setup - Usage Examples

## Overview

The `setup-yubikey-sudo.sh` script configures Ubuntu 24.04 to use a YubiKey for sudo authentication via the pam_u2f module. It supports both interactive and fully automated usage.

## Prerequisites

- Ubuntu 24.04 (Noble Numbat)
- YubiKey with FIDO2/U2F support
- Root/sudo privileges
- YubiKey inserted into USB port

## Quick Start

### Interactive Mode (Recommended for First-Time Users)

Simply run the script with sudo:

```bash
sudo ./setup-yubikey-sudo.sh
```

**Expected Prompts:**
1. Mode selection (passwordless or 2FA)
2. Cue prompt preference (show "Please touch the device" or not)
3. Confirmation before making changes
4. YubiKey touch prompt during registration

**Example Session:**
```
========================================================================
           YubiKey Sudo Setup - Interactive Mode
========================================================================

This script will configure your system to use a YubiKey for sudo
authentication via the pam_u2f module.

Select authentication mode:
  1) Passwordless - YubiKey alone grants sudo access (recommended)
  2) Two-Factor (2FA) - Password + YubiKey required

Enter choice [1-2] (default: 1): 1

Enable touch prompt (shows 'Please touch the device')? [Y/n]: y

Configuration:
  Mode: passwordless
  Cue Prompt: Enabled
  User: alice
  Mapping File: /etc/u2f_mappings

This will modify /etc/pam.d/sudo and may affect your ability to use sudo.
Continue? [y/N] y

[INFO] Installing required packages: libpam-u2f pamu2fcfg
[SUCCESS] Packages installed successfully
[INFO] Registering YubiKey for user: alice
[INFO] Origin: pam://hostname.example.com

Please insert your YubiKey and prepare to touch it when prompted.
You may be asked to enter a PIN if your YubiKey requires one.

Press Enter when ready...

[INFO] Touch your YubiKey now...
[SUCCESS] YubiKey registered successfully
[SUCCESS] Mapping saved to: /etc/u2f_mappings
[SUCCESS] Backed up PAM file to: /etc/pam.d/sudo.bak.20260103_120000
[INFO] Adding new pam_u2f.so entry...
[SUCCESS] PAM configuration updated successfully

========================================================================
                    YubiKey Sudo Setup Complete
========================================================================
```

### Legacy Positional Arguments

For backward compatibility:

```bash
# Passwordless mode
sudo ./setup-yubikey-sudo.sh passwordless

# Two-factor mode
sudo ./setup-yubikey-sudo.sh 2fa
```

## Automated Usage

### Basic Automated Setup

**Passwordless with cue (default):**
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
```

**Two-factor authentication:**
```bash
sudo ./setup-yubikey-sudo.sh --mode 2fa --yes
```

### Advanced Automated Examples

**Passwordless without cue prompt:**
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --no-cue --yes
```

**2FA for specific user with custom mapping file:**
```bash
sudo ./setup-yubikey-sudo.sh \
  --mode 2fa \
  --user alice \
  --authfile /custom/path/u2f_mappings \
  --yes
```

**Passwordless with all options explicit:**
```bash
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --cue \
  --user bob \
  --authfile /etc/u2f_mappings \
  --yes
```

**Skip package installation (packages already installed):**
```bash
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --no-install \
  --yes
```

## Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--mode MODE` | Authentication mode: `passwordless` or `2fa` | `passwordless` |
| `--cue` | Enable touch prompt | Enabled |
| `--no-cue` | Disable touch prompt | - |
| `--user USERNAME` | Specify user to enroll | Auto-detect (SUDO_USER) |
| `--authfile PATH` | Custom mapping file path | `/etc/u2f_mappings` |
| `--yes`, `--assume-yes` | Skip interactive confirmations | Interactive |
| `--no-install` | Skip automatic package installation | Auto-install |
| `-h`, `--help` | Show help message | - |

## Testing Your Setup

**CRITICAL:** Always test in a NEW terminal before closing your current session!

### Test Steps

1. Open a new terminal window/tab
2. Clear sudo credentials:
   ```bash
   sudo -k
   ```
3. Test sudo with YubiKey:
   ```bash
   sudo echo SUCCESS
   ```

### Expected Behavior

**Passwordless mode with cue:**
- You see: `Please touch the device.`
- Touch your YubiKey
- Command executes without password

**Passwordless mode without cue:**
- YubiKey LED blinks (no text prompt)
- Touch your YubiKey
- Command executes without password

**2FA mode with cue:**
- You see: `Please touch the device.`
- Touch your YubiKey
- Enter your password
- Command executes

**2FA mode without cue:**
- YubiKey LED blinks
- Touch your YubiKey
- Enter your password
- Command executes

## Rollback / Recovery

If you get locked out of sudo, you can restore the original configuration:

### Method 1: From Another Sudo Session

If you have another terminal with active sudo:

```bash
# Find the backup file
ls -lt /etc/pam.d/sudo.bak.*

# Restore from backup (use the most recent timestamp)
sudo cp /etc/pam.d/sudo.bak.20260103_120000 /etc/pam.d/sudo
```

### Method 2: Recovery Mode

1. Reboot and enter recovery mode (hold Shift during boot)
2. Select "Drop to root shell prompt"
3. Remount filesystem as read-write:
   ```bash
   mount -o remount,rw /
   ```
4. Restore backup:
   ```bash
   cp /etc/pam.d/sudo.bak.* /etc/pam.d/sudo
   ```
5. Reboot:
   ```bash
   reboot
   ```

### Method 3: Live USB

1. Boot from Ubuntu Live USB
2. Mount your system partition
3. Restore the backup file
4. Reboot

## Automation Examples

### Ansible Playbook

```yaml
---
- name: Configure YubiKey sudo authentication
  hosts: workstations
  become: yes
  tasks:
    - name: Copy setup script
      copy:
        src: setup-yubikey-sudo.sh
        dest: /tmp/setup-yubikey-sudo.sh
        mode: '0755'
    
    - name: Run YubiKey setup
      command: >
        /tmp/setup-yubikey-sudo.sh
        --mode passwordless
        --cue
        --user {{ ansible_user }}
        --yes
      args:
        creates: /etc/u2f_mappings
```

### Shell Script Wrapper

```bash
#!/bin/bash
# deploy-yubikey.sh - Deploy YubiKey sudo to multiple users

USERS=("alice" "bob" "charlie")
MODE="passwordless"

for user in "${USERS[@]}"; do
    echo "Setting up YubiKey for $user..."
    sudo ./setup-yubikey-sudo.sh \
        --mode "$MODE" \
        --user "$user" \
        --yes
done
```

### CI/CD Pipeline (GitLab CI)

```yaml
yubikey_setup:
  stage: configure
  script:
    - chmod +x setup-yubikey-sudo.sh
    - ./setup-yubikey-sudo.sh --mode passwordless --yes
  only:
    - main
  tags:
    - physical-hardware
```

## Troubleshooting

### Issue: "Could not detect actual user"

**Solution:** Explicitly specify the user:
```bash
sudo ./setup-yubikey-sudo.sh --user alice --yes
```

### Issue: "Required package 'libpam-u2f' is not installed"

**Solution:** Remove `--no-install` flag or install manually:
```bash
sudo apt-get update
sudo apt-get install -y libpam-u2f pamu2fcfg
```

### Issue: YubiKey not detected during registration

**Checklist:**
- YubiKey is inserted
- YubiKey LED is on
- Try a different USB port
- Check `lsusb` output for Yubico device

### Issue: "Please touch the device" but nothing happens

**Possible causes:**
- YubiKey requires PIN (enter PIN when prompted)
- YubiKey is not in FIDO2 mode
- USB connection issue

### Issue: Locked out of sudo

**Solution:** See "Rollback / Recovery" section above

## Security Considerations

### Backup Strategy

- PAM configuration is automatically backed up with timestamp
- Keep multiple backups in safe location
- Test rollback procedure before deploying to production

### Multi-User Environments

- Each user needs their own YubiKey registration
- Mapping file (`/etc/u2f_mappings`) contains all user mappings
- File permissions: `640` (root:root)

### Physical Security

- YubiKey must be physically present for sudo
- Lost YubiKey = need recovery mode access
- Consider keeping a backup YubiKey registered

### Audit Trail

- PAM logs sudo attempts to `/var/log/auth.log`
- Monitor for failed authentication attempts
- Review backup files periodically

## Advanced Configuration

### Per-User Mapping Files

To use per-user mapping files instead of system-wide:

```bash
# Create user-specific directory
sudo mkdir -p /home/alice/.config/Yubico
sudo chown alice:alice /home/alice/.config/Yubico

# Run setup with custom authfile
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --user alice \
  --authfile /home/alice/.config/Yubico/u2f_keys \
  --yes

# Update PAM manually to use user-specific file
# Edit /etc/pam.d/sudo and change authfile path
```

### Multiple YubiKeys per User

To register multiple YubiKeys for the same user:

```bash
# Register first YubiKey
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Register second YubiKey (append to existing mapping)
sudo su - $USER -c "pamu2fcfg -opam://$(hostname) -ipam://$(hostname)" | \
  sudo tee -a /etc/u2f_mappings
```

### Custom Origin String

The script uses `pam://HOSTNAME` by default. To customize:

1. Edit the script's `get_hostname()` function
2. Or manually edit `/etc/u2f_mappings` and `/etc/pam.d/sudo`

## File Locations

| File | Purpose | Permissions |
|------|---------|-------------|
| `/etc/pam.d/sudo` | PAM configuration for sudo | `644` (root:root) |
| `/etc/pam.d/sudo.bak.*` | Timestamped backups | `644` (root:root) |
| `/etc/u2f_mappings` | YubiKey mappings (default) | `640` (root:root) |
| `/var/log/auth.log` | Authentication logs | `640` (syslog:adm) |

## PAM Configuration Details

### Passwordless Mode

```
auth    sufficient    pam_u2f.so    cue    authfile=/etc/u2f_mappings    origin=pam://hostname
```

- `sufficient`: Success allows immediate authentication
- `cue`: Shows "Please touch the device" prompt
- Falls back to password if YubiKey fails

### 2FA Mode

```
auth    required      pam_u2f.so    cue    authfile=/etc/u2f_mappings    origin=pam://hostname
```

- `required`: Must succeed for authentication
- Used in addition to password authentication
- More secure but requires both factors

## Version History

- **1.0.0** (2026-01-03): Initial release
  - Interactive and automated modes
  - Passwordless and 2FA support
  - Cue prompt configuration
  - Automatic package installation
  - Safe PAM file editing with backups

## Support

For issues, questions, or contributions:
- Check `/var/log/auth.log` for authentication errors
- Review PAM backup files in `/etc/pam.d/`
- Test in a safe environment before production deployment

## License

MIT License - See script header for details
