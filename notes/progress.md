# PHASE 1: Base Setup

Rocky server installed and initialized.
Both adapters detected.

Ping to 8.8.8.8 successful, 5 packets transmitted, 5 received, 0% packet loss.
Ping to 192.168.56.1 successful, 4 packets transmitted, 4 received, 0% packet loss.

Setting server to static IP on the host only adapter:
```
nmcli con mod enp0s3 ipv4.addresses 192.168.56.10/24 ipv4.method manual
```
> **Typo:** typed `enp0s3p` instead of `enp0s3`, reran correctly.

Connection activated: `nmcli con up enp0s3`

Installing basic network tools:
```
dnf install -y vim curl wget net-tools bash-completion
```
Already installed, just ran updates.

Firewall check — enabled and running.

---

# PHASE 2: SSH Hardening

SSH runs on port 22 by default. This phase secures it by closing the gaps attackers commonly exploit. Core principles being applied:
- SSH keys instead of passwords
- Least privilege — no direct root login
- Reduced attack surface — custom port, whitelist of allowed users

Generating SSH key on the host machine using:
```
ssh-keygen -t ed25519 -C "lab-key"
```
This creates two files:
- `~/.ssh/id_ed25519` — private key, never shared
- `~/.ssh/id_ed25519.pub` — public key, this goes on the server

> **Issue:** Static IP was assigned to enp0s3 (NAT) instead of enp0s8 (host-only). See issues.md.

Copied public key to Rocky:
```
ssh-copy-id -p 22 overlord@192.168.56.10
```
Tested key login before locking anything down:
```
ssh -i ~/.ssh/id_ed25519 overlord@192.168.56.10
```
All good.

Created a shortcut profile on Mint so i don't have to type the full command every time `~/.ssh/config`:
```
Host rocky-server
    HostName 192.168.56.10
    User overlord
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
```
Now i can just type `ssh rocky-server` instead of the whole thing.

Edited the SSH daemon config on Rocky:
```
sudo nano /etc/ssh/sshd_config
```

> **Note:** Lines starting with `#` are comments and get ignored entirely. Had to remove the `#` from each line being changed or nothing would apply.

Changes made:

| Setting | Value | Reason |
|---|---|---|
| Port | 2222 | Off default port 22 |
| PermitRootLogin | no | No direct root access |
| PasswordAuthentication | no | Keys only |
| MaxAuthTries | 3 | Drop after 3 failed attempts |
| ClientAliveInterval | 300 | Check for dead sessions every 5 min |
| ClientAliveCountMax | 2 | Drop after 2 missed checks |
| X11Forwarding | no | Not needed, attack vector |
| AllowUsers | overlord | Whitelist — only i can SSH in |

Told SELinux about the new port. It keeps its own list of allowed ports per service and silently blocks anything not on it:
```
sudo semanage port -a -t ssh_port_t -p tcp 2222
```

Updated firewalld — opened 2222 and closed 22:
```
sudo firewall-cmd --add-port=2222/tcp --permanent
sudo firewall-cmd --remove-service=ssh --permanent
sudo firewall-cmd --reload
```

> **Note:** Open the new port before removing the old one. Doing it the other way around locks you out.

Restarted sshd: `sudo systemctl restart sshd`
Confirmed listening on 2222 via `sudo systemctl status sshd`.

> **Note:** After assigning enp0s8 to the internal zone in phase 3, port 2222 had to be added to the internal zone too — not just public. Traffic coming in on enp0s8 hits internal zone rules, not public.

Verified:
- `ssh -p 2222 overlord@192.168.56.10` — connected fine
- `ssh -p 2222 root@192.168.56.10` — rejected

---

# PHASE 3: Firewall Zones + fail2ban

Two goals — apply different trust levels to each network adapter, and automatically ban IPs that fail login too many times.

**firewalld zones** let you define how much you trust traffic on a given interface. The NAT adapter and the host-only adapter shouldn't be treated the same.

**fail2ban** watches log files and dynamically adds firewall rules to block IPs that show suspicious patterns like repeated failed logins.

Assigned zones:
```
sudo firewall-cmd --zone=public --change-interface=enp0s3 --permanent
sudo firewall-cmd --zone=internal --change-interface=enp0s8 --permanent
sudo firewall-cmd --reload
```
- `enp0s3` (NAT) → public, untrusted
- `enp0s8` (host-only) → internal, trusted lab network

Removed dhcpv6-client from public zone — not using IPv6, no reason to have it open:
```
sudo firewall-cmd --zone=public --remove-service=dhcpv6-client --permanent
```

Installed fail2ban — it's not in the default Rocky repos so needed EPEL first:
```
sudo dnf install -y epel-release
sudo dnf install -y fail2ban
```

Configured `/etc/fail2ban/jail.local`:
```ini
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
backend  = systemd

[sshd]
enabled = true
port    = 2222
logpath = %(sshd_log)s
```

- `bantime` — how long the ban lasts
- `findtime` — window to count failures within
- `maxretry` — failures before ban triggers
- `backend systemd` — Rocky logs through journald not flat files, so this is needed
- `port 2222` — has to match the SSH port from phase 2

Enabled and started fail2ban:
```
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

Triggered a ban on purpose by failing login repeatedly from Mint, checked with:
```
sudo fail2ban-client status sshd
```
Showed `Currently banned: 1`.

Unbanned self: `sudo fail2ban-client set sshd unbanip 192.168.56.1`

> **Note:** fail2ban only blocks new connections — it does not kill existing sessions. Close the SSH session before testing or you'll stay connected through the ban and think it didn't work.

---

# PHASE 4: CIS Benchmark Audit Script

CIS (Center for Internet Security) publishes a checklist of security controls a well configured Linux server should have. Instead of checking each item manually every time, wrote a bash script that does it automatically and spits out a pass/fail report.

Checks covered:
- SSH config
- Password policies
- File permissions
- Kernel parameters
- Unnecessary services
- SELinux and firewall status

Created the script at `~/scripts/cis-audit.sh` and made it executable:
```
chmod +x ~/scripts/cis-audit.sh
```

> **Note:** OpenSCAP will be used later for a proper multi-system audit. The custom script is for learning what each check actually means.

First run results — 8 fails:

**SSH:**
- `[FAIL]` Root login not disabled
- `[FAIL]` MaxAuthTries not set or too high

**Password Policies:**
- `[FAIL]` PASS_MAX_DAYS is 99999 (should be ≤90)
- `[FAIL]` PASS_MIN_DAYS is 0 (should be ≥7)
- `[FAIL]` PASS_MIN_LEN not set (should be ≥12)

**File Permissions:**
- `[FAIL]` /etc/shadow permissions wrong

**Kernel Parameters:**
- `[FAIL]` ICMP redirects enabled
- `[FAIL]` Reverse path filtering disabled

> **Issue:** Script was showing both PASS and FAIL for root login simultaneously. See issues.md.

**Fixing the fails:**

Password policy — edited `/etc/login.defs`:
- `PASS_MAX_DAYS 90` — max days before password expires
- `PASS_MIN_DAYS 7` — min days between password changes
- `PASS_MIN_LEN 12` — minimum password length
- `PASS_WARN_AGE 7` — warn user 7 days before expiry

Shadow permissions:
```
sudo chmod 640 /etc/shadow
```

Kernel parameters — created `/etc/sysctl.d/99-cis.conf`:
```
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
```
Applied with: `sudo sysctl --system`

Final result:
```
PASS: 22 | FAIL: 0 | WARN: 0
```

Saved report to file:
```
sudo bash ~/scripts/cis-audit.sh | tee ~/scripts/audit-report.txt
```

---

# PHASE 5: Filesystem Integrity with AIDE

AIDE (Advanced Intrusion Detection Environment) takes a snapshot of the filesystem and keeps it as a baseline database. Running it again later shows exactly what changed — catches an attacker who sneakily modified a file or binary, or catches me if i screw something up.

Installed AIDE:
```
sudo dnf install -y aide
```

Initialized the baseline database:
```
sudo aide --init
```
This scans everything defined in `/etc/aide.conf` and builds the database. Takes a few minutes — it's hashing every watched file.

Output:
```
Start timestamp: 2026-05-01 13:56:07 +0800 (AIDE 0.16)
AIDE initialized database at /var/lib/aide/aide.db.new.gz
```

Renamed to the active database name:
```
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
```

> **Note:** AIDE writes new scans to `aide.db.new.gz` and reads the baseline from `aide.db.gz`. They're kept separate so a scan never overwrites the reference point. You manually promote a new scan to baseline when you're happy with it.

First check — nothing changed so it came back clean:
```
AIDE found NO differences between database and filesystem. Looks okay!!
```

Tampered with something on purpose:
```
echo "# aide test" | sudo tee -a /etc/hosts
```

> **Note:** `sudo echo "text" >> file` doesn't work — sudo only elevates the echo, not the redirect. Use `tee -a` instead.

AIDE caught it:
```
AIDE found differences between database and filesystem!!
```

Undid the tamper, checked again:
```
AIDE found NO differences between database and filesystem. Looks okay!!
```

When making legitimate changes like installing packages, update the baseline so AIDE doesn't keep alerting on known good changes:
```
sudo aide --update
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
```

> **Note:** Always review what changed before promoting a new baseline. Blindly updating bakes an attacker's modifications into the reference — defeating the whole point.

Set up daily automated check using cron:
```
sudo crontab -e
```
Added:
```
0 3 * * * /usr/sbin/aide --check >> /var/log/aide-check.log 2>&1
```
`0 3 * * *` = 3:00am every day. `2>&1` sends errors to the same log file so nothing gets silently swallowed.

Verified with `sudo crontab -l`.

---

# PHASE 6: Centralized Audit Log Pipeline

Logs sitting only on Rocky is a problem — if an attacker compromises the server, first thing they do is clear the logs. If those logs already shipped to another machine, too late, we already have them.

Two machines involved:
- **AllSeeingEye (Rocky)** — generates and forwards logs
- **ServantOfTheEye (Kubuntu)** — receives and stores them

## Getting Kubuntu on the network

Adapters detected but enp0s3 had no IP — same NAT Network vs plain NAT issue as Rocky. Fixed by changing Adapter 1 to plain NAT in VirtualBox settings.

enp0s8 got `192.168.56.4` from DHCP which works but isn't good enough — DHCP can give a different IP every reboot. If Rocky is configured to forward logs to `.4` and Kubuntu boots up as `.7`, the whole pipeline breaks. Static IPs mean every machine always knows where every other machine is, no surprises.

Set enp0s8 to static `192.168.56.30`:
```
sudo nmcli con mod "Wired connection 2" ipv4.addresses 192.168.56.30/24 ipv4.method manual
sudo nmcli con up "Wired connection 2"
```

Final state:
- `enp0s3` → `10.0.2.15` (NAT)
- `enp0s8` → `192.168.56.30` (host-only)

Test pings from Rocky and Mint — both 0% packet loss.

## Configuring auditd rules on Rocky

auditd is the Linux audit daemon — watches for specific system events and logs them. Added custom rules to track the stuff that matters for security.

Created `/etc/audit/rules.d/99-security.rules`:
```
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/ssh/sshd_config -p wa -k ssh_config
-a always,exit -F arch=b64 -S open -F exit=-EACCES -k access_denied
-a always,exit -F arch=b64 -S setuid -k privilege_escalation
-w /etc/audit/ -p wa -k audit_config
```

Flag reference:
- `-w` — watch this file or directory
- `-p wa` — trigger on writes and attribute changes
- `-k` — tag for searching related events later
- `-a always,exit` — log this syscall every time it exits
- `-F arch=b64` — 64-bit architecture
- `-S` — which syscall to watch

Applied rules: `sudo augenrules --load`
Verified: `sudo auditctl -l`

Tested by triggering a watched file access:
```
sudo cat /etc/shadow
sudo ausearch -k identity
```
Got a log entry — auditd is watching.

## Setting up rsyslog on Kubuntu to receive logs

Edited `/etc/rsyslog.conf` — uncommented the TCP/UDP listener modules on port 514:
```
module(load="imudp")
input(type="imudp" port="514")

module(load="imtcp")
input(type="imtcp" port="514")
```
UDP is faster but can drop packets, TCP is reliable — enabled both.

Added rule to store Rocky's logs in their own file:
```
if $fromhost-ip startswith '192.168.56.10' then {
    action(type="omfile" file="/var/log/rocky-server.log")
    stop
}
```
`stop` means don't also write it to the default log files — keeps things tidy.

Opened port 514:
```
sudo ufw allow 514/tcp
sudo ufw allow 514/udp
```

> **Issue:** rsyslog.conf had a syntax error on line 54 with the `==` filter syntax — newer rsyslog versions don't accept it. Fixed by switching to the `startswith` syntax with the action block format. See issues.md.

## Setting up rsyslog on Rocky to forward logs

Created `/etc/rsyslog.d/99-forward.conf`:
```
*.* action(type="omfwd"
    target="192.168.56.30"
    port="514"
    protocol="tcp"
    action.resumeRetryCount="100"
    queue.type="linkedList"
    queue.size="10000")
```
`*.*` forwards all facilities and severities. The queue settings mean if Kubuntu is temporarily unreachable, Rocky queues up to 10000 messages locally and retries rather than dropping them.

Opened port 514 on Rocky's firewall:
```
sudo firewall-cmd --add-port=514/tcp --permanent
sudo firewall-cmd --add-port=514/udp --permanent
sudo firewall-cmd --reload
```

Restarted rsyslog on both machines.

## Verifying the pipeline

Generated log traffic on Rocky:
```
sudo systemctl restart sshd
logger "The All Seeing Eye never rests"
```

Checked on Kubuntu:
```
sudo tail -f /var/log/rocky-server.log
```
Logs arriving from `192.168.56.10` — pipeline confirmed working.
