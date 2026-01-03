# YubiKey Sudo Setup - Quick Reference Card

## One-Line Commands

### Interactive Setup
```bash
sudo ./setup-yubikey-sudo.sh
```

### Automated Passwordless (Recommended)
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
```

### Automated 2FA
```bash
sudo ./setup-yubikey-sudo.sh --mode 2fa --yes
```

### Silent Mode (No Touch Prompt)
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --no-cue --yes
```

## Testing (ALWAYS DO THIS!)

```bash
# In a NEW terminal:
sudo -k
sudo echo SUCCESS
# Touch YubiKey when prompted
```

## Rollback

```bash
# Find backup
ls -lt /etc/pam.d/sudo.bak.*

# Restore (replace timestamp)
sudo cp /etc/pam.d/sudo.bak.20260103_120000 /etc/pam.d/sudo
```

## Common Options

| Option | Description |
|--------|-------------|
| `--mode passwordless` | YubiKey only (no password) |
| `--mode 2fa` | Password + YubiKey |
| `--cue` | Show "Please touch the device" |
| `--no-cue` | Silent (LED blinks only) |
| `--user alice` | Enroll specific user |
| `--authfile /path` | Custom mapping file |
| `--yes` | Skip confirmations |
| `--no-install` | Don't install packages |
| `--help` | Show help |

## File Locations

```
/etc/pam.d/sudo              # PAM configuration
/etc/pam.d/sudo.bak.*        # Backups (timestamped)
/etc/u2f_mappings            # YubiKey mappings
/var/log/auth.log            # Authentication logs
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Locked out | Boot recovery mode, restore backup |
| "User not detected" | Use `--user USERNAME` |
| YubiKey not working | Check `lsusb`, try different port |
| No touch prompt | Add `--cue` option |
| Packages missing | Remove `--no-install` |

## Recovery Mode Steps

1. Reboot, hold Shift
2. Advanced → Recovery mode
3. Drop to root shell
4. `mount -o remount,rw /`
5. `cp /etc/pam.d/sudo.bak.* /etc/pam.d/sudo`
6. `reboot`

## Security Checklist

- [ ] Tested in VM first
- [ ] Tested in new terminal
- [ ] Backup YubiKey registered
- [ ] Recovery method available
- [ ] Team knows rollback procedure
- [ ] Monitoring auth.log

## PAM Line Reference

**Passwordless with cue:**
```
auth  sufficient  pam_u2f.so  cue  authfile=/etc/u2f_mappings  origin=pam://hostname
```

**2FA with cue:**
```
auth  required    pam_u2f.so  cue  authfile=/etc/u2f_mappings  origin=pam://hostname
```

**Without cue (remove `cue` option):**
```
auth  sufficient  pam_u2f.so  authfile=/etc/u2f_mappings  origin=pam://hostname
```

## Multiple YubiKeys

```bash
# Register first
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Add second (manual)
sudo su - $USER -c "pamu2fcfg -opam://$(hostname) -ipam://$(hostname)" | \
  sudo tee -a /etc/u2f_mappings
```

## Automation Examples

**Ansible:**
```yaml
- command: /path/to/setup-yubikey-sudo.sh --mode passwordless --yes
```

**Shell loop:**
```bash
for user in alice bob; do
  sudo ./setup-yubikey-sudo.sh --mode passwordless --user $user --yes
done
```

**Cron (not recommended - requires physical YubiKey):**
```bash
# Don't use cron for initial setup - requires user interaction
```

## Expected Prompts

**Interactive mode:**
1. Mode selection (1 or 2)
2. Cue preference (Y/n)
3. Confirmation (y/N)
4. "Press Enter when ready..."
5. "Touch your YubiKey now..."

**Automated mode:**
1. "Touch your YubiKey now..." (only prompt)

**Testing sudo:**
- With cue: "Please touch the device."
- Without cue: (LED blinks, no text)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (check message) |

## Help

```bash
./setup-yubikey-sudo.sh --help
```

## Version

```bash
grep "readonly SCRIPT_VERSION" setup-yubikey-sudo.sh
# Version: 1.0.0
```

---

**⚠️ ALWAYS TEST IN NEW TERMINAL BEFORE CLOSING CURRENT SESSION!**

**📖 Full documentation:** See README.md, USAGE_EXAMPLES.md, TEST_SCENARIOS.md
