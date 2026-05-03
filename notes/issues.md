# Issues Log

A running log of problems hit during the lab, what caused them, and how they were fixed.

---

## Issue 1 — Wrong adapter got the static IP (Phase 1/2)

**What happened:**
Static IP `192.168.56.10` was assigned to `enp0s3` (NAT adapter) instead of `enp0s8` (host-only adapter). This caused a subnet collision — both adapters ended up on the `192.168.56.x` range, making the server unreachable from the host.

**Root cause:**
Adapter 1 was set to NAT Network (ServerNetwork) instead of plain NAT. VirtualBox's DHCP handed it an IP in the same `192.168.56.x` range as the host-only adapter.

**Fix:**
Changed Adapter 1 in VirtualBox settings from NAT Network → plain NAT. Removed static IP from enp0s3 and restored DHCP. Created a proper connection profile on enp0s8 with the static IP.

---

## Issue 2 — sshd_config changes not applying (Phase 2)

**What happened:**
SSH settings changed in `/etc/ssh/sshd_config` but had no effect after restarting sshd.

**Root cause:**
Config file lines starting with `#` are comments — they are completely ignored by sshd. The default config has most settings commented out as examples. Changing the value without removing the `#` does nothing.

**Fix:**
Removed the `#` from the start of each line being changed.

---

## Issue 3 — Port 2222 blocked after zone change (Phase 2/3)

**What happened:**
SSH on port 2222 stopped working after assigning enp0s8 to the `internal` firewalld zone in Phase 3.

**Root cause:**
The port 2222 firewall rule was added to the `public` zone. After reassigning enp0s8 to `internal`, traffic coming in on that interface hits the `internal` zone rules — which had no rule for port 2222.

**Fix:**
```
sudo firewall-cmd --zone=internal --add-port=2222/tcp --permanent
sudo firewall-cmd --reload
```

---

## Issue 4 — CIS script double result for PermitRootLogin (Phase 4)

**What happened:**
The audit script was outputting both `[PASS] Root login disabled` and `[FAIL] Root login NOT disabled` at the same time.

**Root cause:**
Rocky's sshd has an include system — `/etc/ssh/sshd_config.d/` contains additional config files that get merged in. The script was grepping the main sshd_config file but the include chain was causing double matches. Also `50-redhat.conf` in that directory had its own `X11Forwarding yes` line overriding the `no` set in the main config.

**Fix:**
Used `sshd -T` instead of grepping the config file directly. `sshd -T` dumps the full effective running config after all includes are resolved, in lowercase. Switched the root login check to an if/else block:
```bash
if sshd -T | grep -q "permitrootlogin no"; then
  pass "Root login disabled"
else
  fail "Root login NOT disabled"
fi
```
Also fixed X11Forwarding by changing it to `no` directly in `50-redhat.conf`.

---

## Issue 5 — sudo redirect permission denied (Phase 5)

**What happened:**
```
sudo echo "# aide test" >> /etc/hosts
-bash: /etc/hosts: Permission denied
```

**Root cause:**
`sudo` only elevates the `echo` command — the shell handles the `>>` redirect before sudo gets involved, and the shell runs as the regular user who doesn't have write permission to `/etc/hosts`.

**Fix:**
```
echo "# aide test" | sudo tee -a /etc/hosts
```
`tee -a` runs as sudo and handles the write itself.

---

## Issue 6 — rsyslog syntax error on Kubuntu (Phase 6)

**What happened:**
rsyslog failed to parse `/etc/rsyslog.conf` with:
```
syntax error on token '==' [v8.2512.0]
could not interpret master config file '/etc/rsyslog.conf'
```

**Root cause:**
The filter rule added used the old rsyslog syntax:
```
if $fromhost-ip == '192.168.56.10' then /var/log/rocky-server.log
```
Newer rsyslog versions (v8+) don't accept this syntax.

**Fix:**
Replaced with the modern RainerScript syntax:
```
if $fromhost-ip startswith '192.168.56.10' then {
    action(type="omfile" file="/var/log/rocky-server.log")
    stop
}
```

**Lesson:**
rsyslog has two config syntaxes — the old legacy format and the newer RainerScript format. On modern distros always use RainerScript. If you see a syntax error mentioning `==` or similar tokens, that's the old format being rejected.+