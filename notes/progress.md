# PHASE 1
Rocky server installed and initialized.<br>
both adapters detected.<br>
ping to 8.8.8.8 succesful, 5 packets transmitted, 5 recieved , 0% packet loss<br>
ping to 192.168.56.1 succesful, 4 packets transmitted, 4 recieved 0% packet lost<br>

setting server to static ip on the host only adapter using command ``nmcli con mod enp0s3 ipv4.addresses 192.168.56.10/24 ipv4.method manual``<br>
slight issue, typo detected `enp0s3p` typed instead of `enp0s3`<br>
connection activated using `nmcli con up enp0s3`<br>

now installing basic network tools `dnf install -y vim curl wget net-tools bash-completion`<br>
already installed so just an update<br>
checked if firewall as all good, enabled and running.<br>


# Phase 2: SSH hardening

ssh runs on prt 22, in this phase we secure it from hackers closing the leaks and gaps. core principle sbeing applied are:
- SSH keys
- least privilage or no direct root login
- Reduced attack surface, limiting who can connect

Generating SSH key on out host machine using `ssh-keygen -t ed25519 -C "lab-key"`<br>
here we create a private key that i keep to myself and a public key that is what i'll be putting into the server<br>
- ~/.ssh/id_ed25519 (private)
- ~/.ss/id_ed25519.pub (public)

# **ISSUE!!** 
static ip given to  enp0s3(NAT) instead of enp0s8(host only).
sovled by removing the static ip from enp0s3 and putting it back on dhcp, coz well nat need dhcp<br>
``sudo nmcli con mod enp0s3 ipv4.method auto ipv4.addresses ""``<br>
``sudo nmcli con up enp0s3``<br>

then creating a proper profile on the host only adapter enp0s8:<br>
``sudo nmcli con add type ethernet ifname enp0s8 con-name host-only``<br>
``sudo nmcli con mod host-only ipv4.addresses 192.168.56.10/24 ipv4.method manual``<br>
``sudo nmcli con upp host-only``<br>

a quick `ip a` to check if correct and. . .*cue drum roll*<br>
all good.

## continuing
copied public key to rocky using ``ssh-copy-id -p 22 overlord@192.168.56.10``
tested key login before changing anything to make sure it works before locking things down
``ssh -i ~/.ssh/id_ed25519 overlord@192.168.56.10``: all good

edited the ssh daemon config on rocky: ``sudo nano /etc/ssh/sshd_config``<br>

*note: lines starting with # are comments and get ignored entirely, had to remove the # from each line i was changing or nothing would apply*

| Setting | Value | Reason |
|---|---:|---|
| Port | 2222 | Use non-default port instead of 22 |
| PermitRootLogin | no | Prevent direct root access |
| PasswordAuthentication | no | Require key-based auth only |
| MaxAuthTries | 3 | Drop connection after 3 failed attempts |
| ClientAliveInterval | 300 | Check for dead sessions every 5 minutes |
| ClientAliveCountMax | 2 | Drop after 2 missed alive checks |
| X11Forwarding | no | Not needed; reduces attack surface |
| AllowUsers | overlord | Whitelist: only this user may SSH in |

told SELinux about the new port, it keeps its own list of allowed ports per service and silently blocks anything not on it:<br>

``sudo semanage port -a -t ssh_port_t -p tcp 2222``<br>

updated firewalld, opened 2222 and closed 22:<br>
``sudo firewall-cmd --add-port=2222/tcp --permanent``<br>
``sudo firewall-cmd --remove-service=ssh --permanent``<br>
``sudo firewall-cmd --reload``<br>

restarted sshd: ``sudo systemctl restart sshd``

confirmed it was listening on 2222 via ``sudo systemctl status sshd``

*note: after assigning enp0s8 to the internal zone in phase 3, port 2222 had to be added to internal zone too, not just public. traffic coming in on enp0s8 hits internal zone rules, not public.*

verified:<br>
```ssh -p 2222 overlord@192.168.56.10 connected fine ```<br>
```ssh -p 2222 root@192.168.56.10 got rejected```<br>


# **Phase 3: Firewall zones + fail2ban**

assigned zones:

- ``sudo firewall-cmd --zone=public --change-interface=enp0s3 --permanent``
- ``sudo firewall-cmd --zone=internal --change-interface=enp0s8 --permanent``
- ``sudo firewall-cmd --reload``

enp0s3 (NAT) -> public, untrusted<br>
enp0s8 (host-only) -> internal, trusted lab network<br>

removed dhcpv6-client from public zone, not using IPv6 so no reason to have it open:

``sudo firewall-cmd --zone=public --remove-service=dhcpv6-client --permanent``

installed fail2ban, its not in the default rocky repos so needed EPEL first:

- ``sudo dnf install -y epel-release``
- ``sudo dnf install -y fail2ban``

configured /etc/fail2ban/jail.local:

[DEFAULT]<br>
bantime = 1h<br>
findtime = 10m<br>
maxretry = 5<br>
backend = systemd<br>
<br>
[sshd]<br>
enabled = true<br>
port = 2222<br>
logpath = /var/log/auth.log<br>

bantime: how long the ban lasts<br>
findtime: window to count failures within<br>
maxretry: failures before ban triggers<br>
backend systemd: rocky logs through journald not flat files so this is needed<br>
port 2222: has to match the ssh port from phase 2<br>

enabled and started fail2ban:<br>
```sudo systemctl enable fail2ban```<br>
```sudo systemctl start fail2ban```<br>

# **PHASE 4: CIS Benchmark Audir Script**

Centre for internet security publishes a checklist of security controls a good linux server should have.<br>
gonna write a bash script to do it automatically :3

checks:
- SSH config
- password policies
- file permissions
- kernel parameters
- unnecesarry servies
- SELinux and firewall status

after the custom cis sript i make it runnable using ``chmod +x ~/scripts/cis-audit.sh``<br>

*note OpenSCAP will be used later, just learning how it works*

after running, i got 8 fails.

### SSH
- [FAIL] Root login NOT disabled
- [FAIL] MaxAuthTries not set or too high
### password policies
- [FAIL] PASS_MAX_DAYS is 99999 (should be 90 or less)
- [FAIL] PASS_MIN_DAYS is 0 (should be 7 or more)
- [FAIL] PASS_MIN_LEN is  (should be 12 or more)
### Critical File Permissions
- [FAIL] /etc/shadow is 0 (should be 000 or 640)
### Kernel Parameters
- [FAIL] ICMP redirects enabled
- [FAIL] Reverse path filtering disabled 

WELL, time to get fixing. starting with the ssh fails

*note! special fail:*
```--- SSH Configuration ---
[PASS] Root login disabled
[FAIL] Root login NOT disabled
```
*hmm, no double line in the sshd condig. . .maybe i screwed up the cis script?*
*huh. . .ok max tries fixed but, no luck on the double. . .*
*not really sure why it failed but using grep in the bash made root login check double, but if else workls so hey we good.*
<br>
moving on
time to solve the other fails.

##Password policy:

starting with ``sudo nano /etc/login.defs``
Here we're going to change **PASS_MAX_DAYS**, to setup the maximum days a password is ok to be used before expiring to a value below 90 to satisfy security reqs(we'll set it to 90)

and also **PASS_MIN_DAYS** which is the minimum number of days allowed between password changes. setting that to 7 days aka you have to wait a week before changing your password again

**PASS_WARN_AGE** is the number of days before a password expires, ex: "YOU PASSWORD EXPIRES IN 7 DAYS!"

**PASS_MIN_LEN** minmum acceptable length for passwords, i'll set it to 12

next, the shadow permisions. we fix that easy enought by typing ``sudo chmod 640 /etc/shadow``

nextnext and hopefully last, the kernel parameters. ``sudo nano /etc/sysctl.d/99-cis.conf``
 in the new file we add:
```
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
```
and then i apply the setting with ``sudo sysctl --system``

and one last check, drum roll please. . .

> **********************************
>  PASS: 22 | FAIL: 0 | WARN: 0
> **********************************

Great success

# **PHASE 5:**
