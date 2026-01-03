# Test Scenarios for setup-yubikey-sudo.sh

## Test Environment Setup

These tests assume:
- Fresh Ubuntu 24.04 installation
- User has sudo privileges
- YubiKey is available for physical tests

## Unit Tests (No YubiKey Required)

### Test 1: Help Display
```bash
./setup-yubikey-sudo.sh --help
```
**Expected:** Help text displays, exit code 0

### Test 2: Syntax Validation
```bash
bash -n setup-yubikey-sudo.sh
```
**Expected:** No syntax errors

### Test 3: Root Check (Non-Root)
```bash
./setup-yubikey-sudo.sh --mode passwordless --yes
```
**Expected:** Error message "This script must be run as root", exit code 1

### Test 4: Invalid Mode
```bash
sudo ./setup-yubikey-sudo.sh --mode invalid --yes
```
**Expected:** Error message "Invalid mode: invalid", exit code 1

### Test 5: Missing Required Argument
```bash
sudo ./setup-yubikey-sudo.sh --mode
```
**Expected:** Error message "Option --mode requires an argument", exit code 1

### Test 6: Unknown Option
```bash
sudo ./setup-yubikey-sudo.sh --unknown-option
```
**Expected:** Error message "Unknown option: --unknown-option", exit code 1

## Integration Tests (Require YubiKey)

### Test 7: Interactive Mode - Passwordless
```bash
sudo ./setup-yubikey-sudo.sh
```
**Steps:**
1. Select option 1 (passwordless)
2. Accept cue prompt (Y)
3. Confirm changes (y)
4. Touch YubiKey when prompted

**Expected:**
- Packages installed (if not present)
- YubiKey registered
- PAM file backed up
- PAM file updated with pam_u2f.so line
- Success message displayed

**Verify:**
```bash
# Check backup exists
ls -l /etc/pam.d/sudo.bak.*

# Check PAM configuration
grep pam_u2f.so /etc/pam.d/sudo

# Expected line:
# auth    sufficient    pam_u2f.so    cue    authfile=/etc/u2f_mappings    origin=pam://HOSTNAME

# Check mapping file
sudo cat /etc/u2f_mappings
# Should contain: username:keyHandle,publicKey

# Test sudo
sudo -k
sudo echo SUCCESS
# Should prompt "Please touch the device."
```

### Test 8: Interactive Mode - 2FA
```bash
sudo ./setup-yubikey-sudo.sh 2fa
```
**Steps:**
1. Mode is pre-selected as 2fa
2. Accept cue prompt (Y)
3. Confirm changes (y)
4. Touch YubiKey when prompted

**Expected:**
- Similar to Test 7 but PAM line uses "required" instead of "sufficient"

**Verify:**
```bash
grep pam_u2f.so /etc/pam.d/sudo
# Expected line:
# auth    required      pam_u2f.so    cue    authfile=/etc/u2f_mappings    origin=pam://HOSTNAME

# Test sudo
sudo -k
sudo echo SUCCESS
# Should prompt "Please touch the device." AND ask for password
```

### Test 9: Automated Mode - Passwordless with Cue
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --cue --yes
```
**Expected:**
- No interactive prompts except YubiKey touch
- Packages installed automatically
- YubiKey registered
- PAM configured with cue option

**Verify:**
```bash
grep "cue" /etc/pam.d/sudo
# Should find cue option in pam_u2f.so line
```

### Test 10: Automated Mode - Passwordless without Cue
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --no-cue --yes
```
**Expected:**
- No cue option in PAM configuration

**Verify:**
```bash
grep pam_u2f.so /etc/pam.d/sudo
# Should NOT contain "cue" option

# Test sudo
sudo -k
sudo echo SUCCESS
# YubiKey LED blinks but no text prompt
```

### Test 11: Automated Mode - 2FA without Cue
```bash
sudo ./setup-yubikey-sudo.sh --mode 2fa --no-cue --yes
```
**Expected:**
- PAM line uses "required"
- No cue option

**Verify:**
```bash
grep pam_u2f.so /etc/pam.d/sudo | grep required
# Should find "required" control
grep pam_u2f.so /etc/pam.d/sudo | grep cue
# Should return nothing (exit code 1)
```

### Test 12: Custom Authfile
```bash
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --authfile /tmp/custom_u2f_mappings \
  --yes
```
**Expected:**
- Mapping saved to /tmp/custom_u2f_mappings
- PAM line references custom authfile

**Verify:**
```bash
ls -l /tmp/custom_u2f_mappings
grep "authfile=/tmp/custom_u2f_mappings" /etc/pam.d/sudo
```

### Test 13: Specific User Enrollment
```bash
# Create test user
sudo useradd -m testuser

# Enroll testuser
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --user testuser \
  --yes

# Verify
sudo cat /etc/u2f_mappings | grep testuser
```

### Test 14: Update Existing Configuration
```bash
# First setup: passwordless with cue
sudo ./setup-yubikey-sudo.sh --mode passwordless --cue --yes

# Update: change to 2fa without cue
sudo ./setup-yubikey-sudo.sh --mode 2fa --no-cue --yes
```
**Expected:**
- Existing pam_u2f.so line is updated (not duplicated)
- New backup created
- Configuration reflects 2fa mode without cue

**Verify:**
```bash
# Should only have ONE pam_u2f.so line
grep -c pam_u2f.so /etc/pam.d/sudo
# Expected: 1

# Should be "required" not "sufficient"
grep pam_u2f.so /etc/pam.d/sudo | grep required

# Should NOT have cue
! grep pam_u2f.so /etc/pam.d/sudo | grep cue
```

### Test 15: No-Install Flag (Packages Already Installed)
```bash
# Ensure packages are installed
sudo apt-get install -y libpam-u2f pamu2fcfg

# Run with --no-install
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --no-install \
  --yes
```
**Expected:**
- No apt-get commands executed
- Setup completes successfully

### Test 16: No-Install Flag (Packages Missing)
```bash
# Remove packages
sudo apt-get remove -y libpam-u2f pamu2fcfg

# Try to run with --no-install
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --no-install \
  --yes
```
**Expected:**
- Error message about missing packages
- Exit code 1

### Test 17: Multiple YubiKeys for Same User
```bash
# Register first YubiKey
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Note the mapping
sudo cat /etc/u2f_mappings

# Insert second YubiKey and register again
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
```
**Expected:**
- First mapping is replaced by second
- Only one entry per user in mapping file

**To register multiple keys (manual):**
```bash
# After first registration, manually append second key
sudo su - $USER -c "pamu2fcfg -opam://$(hostname) -ipam://$(hostname)" | \
  sudo tee -a /etc/u2f_mappings
```

### Test 18: Rollback Test
```bash
# Setup YubiKey sudo
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Note the backup file
BACKUP=$(ls -t /etc/pam.d/sudo.bak.* | head -1)
echo "Backup: $BACKUP"

# Rollback
sudo cp "$BACKUP" /etc/pam.d/sudo

# Verify rollback
grep pam_u2f.so /etc/pam.d/sudo
# Should return nothing (exit code 1) if this was first setup
```

## Edge Cases

### Test 19: PAM File Without @include common-auth
```bash
# Backup original
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.original

# Create minimal PAM file
sudo tee /etc/pam.d/sudo > /dev/null << 'EOF'
#%PAM-1.0
auth       required   pam_env.so
session    required   pam_limits.so
EOF

# Run setup
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Verify pam_u2f.so was added
grep pam_u2f.so /etc/pam.d/sudo

# Restore original
sudo cp /etc/pam.d/sudo.original /etc/pam.d/sudo
```

### Test 20: Concurrent Execution (Race Condition)
```bash
# NOT RECOMMENDED - for testing only
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes &
sudo ./setup-yubikey-sudo.sh --mode 2fa --yes &
wait
```
**Expected:**
- One should succeed, one may fail
- No corruption of PAM file (atomic operations)

### Test 21: Disk Full Scenario
```bash
# Create small filesystem (requires root)
sudo dd if=/dev/zero of=/tmp/small.img bs=1M count=10
sudo mkfs.ext4 /tmp/small.img
sudo mkdir -p /tmp/smallfs
sudo mount /tmp/small.img /tmp/smallfs

# Try to use it as authfile
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --authfile /tmp/smallfs/u2f_mappings \
  --yes

# Fill the filesystem
sudo dd if=/dev/zero of=/tmp/smallfs/fill bs=1M count=9

# Try again (should fail gracefully)
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --authfile /tmp/smallfs/u2f_mappings \
  --yes

# Cleanup
sudo umount /tmp/smallfs
sudo rm /tmp/small.img
```

## Performance Tests

### Test 22: Large Mapping File
```bash
# Create mapping file with 1000 users
for i in {1..1000}; do
  echo "user$i:keyHandle$i,publicKey$i" | sudo tee -a /etc/u2f_mappings
done

# Add real user
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Test sudo performance
time sudo -k
time sudo echo SUCCESS
```

## Security Tests

### Test 23: File Permissions
```bash
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes

# Check authfile permissions
ls -l /etc/u2f_mappings
# Expected: -rw-r----- 1 root root

# Check PAM file permissions
ls -l /etc/pam.d/sudo
# Expected: -rw-r--r-- 1 root root

# Check backup permissions
ls -l /etc/pam.d/sudo.bak.*
# Expected: -rw-r--r-- 1 root root (same as original)
```

### Test 24: Mapping File Injection Attempt
```bash
# Try to inject malicious content via username
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --user "evil;rm -rf /" \
  --yes
```
**Expected:**
- Should fail with "User does not exist" error
- No command injection

### Test 25: Path Traversal in Authfile
```bash
sudo ./setup-yubikey-sudo.sh \
  --mode passwordless \
  --authfile "../../etc/passwd" \
  --yes
```
**Expected:**
- Should create directory structure if needed
- No overwrite of /etc/passwd

## Compatibility Tests

### Test 26: Different Hostname Formats
```bash
# Short hostname
sudo hostnamectl set-hostname testhost
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
grep "origin=pam://testhost" /etc/pam.d/sudo

# FQDN
sudo hostnamectl set-hostname testhost.example.com
sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
grep "origin=pam://testhost.example.com" /etc/pam.d/sudo
```

### Test 27: Non-Interactive Shell
```bash
# Simulate cron/automation environment
sudo bash -c 'export DEBIAN_FRONTEND=noninteractive; ./setup-yubikey-sudo.sh --mode passwordless --yes'
```

### Test 28: Different Locales
```bash
# Test with different locale
sudo LC_ALL=C ./setup-yubikey-sudo.sh --mode passwordless --yes
sudo LC_ALL=en_GB.UTF-8 ./setup-yubikey-sudo.sh --mode passwordless --yes
```

## Regression Tests

### Test 29: Verify All Backups Are Created
```bash
# Count backups before
BEFORE=$(ls /etc/pam.d/sudo.bak.* 2>/dev/null | wc -l)

# Run setup 3 times
for i in 1 2 3; do
  sudo ./setup-yubikey-sudo.sh --mode passwordless --yes
  sleep 1  # Ensure different timestamps
done

# Count backups after
AFTER=$(ls /etc/pam.d/sudo.bak.* 2>/dev/null | wc -l)

# Should have 3 more backups
echo "New backups: $((AFTER - BEFORE))"
# Expected: 3
```

### Test 30: Verify Idempotency
```bash
# Run setup twice with same config
sudo ./setup-yubikey-sudo.sh --mode passwordless --cue --yes
HASH1=$(md5sum /etc/pam.d/sudo | cut -d' ' -f1)

sudo ./setup-yubikey-sudo.sh --mode passwordless --cue --yes
HASH2=$(md5sum /etc/pam.d/sudo | cut -d' ' -f1)

# PAM file should be identical (except for backup creation)
# Note: Mapping file will be updated with new registration
echo "Hash 1: $HASH1"
echo "Hash 2: $HASH2"
```

## Cleanup After Tests

```bash
# Remove test user
sudo userdel -r testuser 2>/dev/null || true

# Restore original PAM configuration
sudo cp /etc/pam.d/sudo.original /etc/pam.d/sudo 2>/dev/null || true

# Remove mapping file
sudo rm -f /etc/u2f_mappings

# Remove backups
sudo rm -f /etc/pam.d/sudo.bak.*

# Remove custom authfiles
sudo rm -f /tmp/custom_u2f_mappings
```

## Automated Test Suite

Here's a simple test runner:

```bash
#!/bin/bash
# test-runner.sh

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Running: $test_name"
    if eval "$test_command"; then
        echo "✓ PASSED: $test_name"
        ((TESTS_PASSED++))
    else
        echo "✗ FAILED: $test_name"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Syntax tests (no YubiKey required)
run_test "Syntax Check" "bash -n setup-yubikey-sudo.sh"
run_test "Help Display" "./setup-yubikey-sudo.sh --help >/dev/null"
run_test "Invalid Mode" "! sudo ./setup-yubikey-sudo.sh --mode invalid --yes 2>/dev/null"

echo "========================================="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "========================================="

exit $TESTS_FAILED
```

## Expected Outcomes Summary

| Test | Expected Result | Exit Code |
|------|----------------|-----------|
| Help display | Help text shown | 0 |
| Syntax check | No errors | 0 |
| Non-root execution | Error message | 1 |
| Invalid mode | Error message | 1 |
| Interactive passwordless | Success, cue enabled | 0 |
| Interactive 2FA | Success, required auth | 0 |
| Automated passwordless | Success, no prompts | 0 |
| Automated 2FA | Success, no prompts | 0 |
| Custom authfile | Success, custom path used | 0 |
| Update existing | Success, single PAM line | 0 |
| No-install (packages present) | Success | 0 |
| No-install (packages missing) | Error message | 1 |
| Rollback | Original config restored | 0 |

## Notes

- Always test in a VM or non-production environment first
- Keep a backup method to access sudo (recovery mode, live USB)
- Some tests require physical YubiKey interaction
- Timing-sensitive tests may need adjustment for slower systems
