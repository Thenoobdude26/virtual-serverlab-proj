!# /usr/bin/env bash
#custom cis script
# Run as: sudo bash ~/scripts/cis-audit.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# helper functions
pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN++)); }
header() { echo -e "\n--- $1 ---"; }

echo "=================================="
echo " CIS Level 1 Audit — $(hostname) — $(date)"
echo "=================================="

# SSH checks
header "SSH Configuration"

grep -q "^PermitRootLogin no$" /etc/ssh/sshd_config \
  && pass "Root login disabled" \
  || fail "Root login NOT disabled"

grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config \
  && pass "Password auth disabled" \
  || fail "Password auth NOT disabled"

grep -q "^MaxAuthTries [1-3]" /etc/ssh/sshd_config \
  && pass "MaxAuthTries is 3 or less" \
  || fail "MaxAuthTries not set or too high"

grep -q "^X11Forwarding no" /etc/ssh/sshd_config \
  && pass "X11Forwarding disabled" \
  || fail "X11Forwarding NOT disabled"

#  Password policies check
header "Password Policies"

PASS_MAX=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
[ "$PASS_MAX" -le 90 ] 2>/dev/null \
  && pass "PASS_MAX_DAYS is $PASS_MAX" \
  || fail "PASS_MAX_DAYS is $PASS_MAX (should be 90 or less)"

PASS_MIN=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}')
[ "$PASS_MIN" -ge 7 ] 2>/dev/null \
  && pass "PASS_MIN_DAYS is $PASS_MIN" \
  || fail "PASS_MIN_DAYS is $PASS_MIN (should be 7 or more)"

PASS_LEN=$(grep "^PASS_MIN_LEN" /etc/login.defs | awk '{print $2}')
[ "$PASS_LEN" -ge 12 ] 2>/dev/null \
  && pass "PASS_MIN_LEN is $PASS_LEN" \
  || fail "PASS_MIN_LEN is $PASS_LEN (should be 12 or more)"

# File permissions check
header "Critical File Permissions"

PASSWD_PERM=$(stat -c "%a" /etc/passwd)
[ "$PASSWD_PERM" = "644" ] \
  && pass "/etc/passwd is 644" \
  || fail "/etc/passwd is $PASSWD_PERM (should be 644)"

SHADOW_PERM=$(stat -c "%a" /etc/shadow)
[ "$SHADOW_PERM" = "000" ] || [ "$SHADOW_PERM" = "640" ] \
  && pass "/etc/shadow is $SHADOW_PERM" \
  || fail "/etc/shadow is $SHADOW_PERM (should be 000 or 640)"

WW_FILES=$(find / -xdev -type f -perm -0002 \
  ! -path "/proc/*" ! -path "/sys/*" ! -path "/dev/*" 2>/dev/null)
[ -z "$WW_FILES" ] \
  && pass "No world-writable files found" \
  || fail "World-writable files found:\n$WW_FILES"

# Kernel parameters
header "Kernel Parameters"

sysctl net.ipv4.ip_forward | grep -q "= 0" \
  && pass "IP forwarding disabled" \
  || fail "IP forwarding enabled"

sysctl net.ipv4.conf.all.accept_redirects | grep -q "= 0" \
  && pass "ICMP redirects disabled" \
  || fail "ICMP redirects enabled"

sysctl net.ipv4.conf.all.rp_filter | grep -q "= 1" \
  && pass "Reverse path filtering enabled" \
  || fail "Reverse path filtering disabled"

# Unnecessary services
header "Unnecessary Services"

for svc in telnet rsh rlogin vsftpd httpd; do
  systemctl is-active --quiet "$svc" \
    && fail "$svc is running" \
    || pass "$svc is not running"
done

# SELinux
header "SELinux"

SELINUX_STATUS=$(getenforce)
[ "$SELINUX_STATUS" = "Enforcing" ] \
  && pass "SELinux is Enforcing" \
  || fail "SELinux is $SELINUX_STATUS"

# Firewall
header "Firewall"

systemctl is-active --quiet firewalld \
  && pass "firewalld is running" \
  || fail "firewalld is NOT running"

systemctl is-active --quiet fail2ban \
  && pass "fail2ban is running" \
  || fail "fail2ban is NOT running"

# Auditd
header "Audit Daemon"

systemctl is-active --quiet auditd \
  && pass "auditd is running" \
  || fail "auditd is NOT running"

# summary of checks
echo ""
echo "=================================="
echo -e " PASS: ${GREEN}$PASS${NC} | FAIL: ${RED}$FAIL${NC} | WARN: ${YELLOW}$WARN${NC}"
echo "=================================="