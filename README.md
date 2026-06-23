# ON HOLD DUE TO HOST OS CHANGING TO ARCH

# Virtual Server Security Lab

A personal home lab project built on VirtualBox, working through Linux server security concepts level by level — kind of like a video game progression. the goal is to go from a fresh Rocky Linux server to a reasonably hardened, monitored, multi-VM environment by the end.

---

## The Lab

| VM | OS | Role | IP |
|---|---|---|---|
| AllSeeingEye | Rocky Linux 9 | primary server — the thing we're hardening | 192.168.56.10 |
| ServantOfTheEye | Kubuntu | client + log collector / SIEM node | 192.168.56.30 |
| TBD | Windows 11 | client machine / attacker box | 192.168.56.20 |

host machine is Linux Mint 22.1, all VMs run on VirtualBox with NAT (internet) + Host-Only (lab traffic) adapters.

---

## Progression

| Level | Name | Status |
|---|---|---|
| 1 | VM setup + base config | done |
| 2 | SSH hardening | done |
| 3 | Firewall zones + fail2ban | done |
| 4 | CIS benchmark audit script | done |
| 5 | Filesystem integrity with AIDE | done |
| 6 | Centralized audit log pipeline | done|
| 7 | Ansible security automation | in progress |
| 8 | Custom SELinux policy module | planned |
| 9 | Internal PKI + mTLS | planned |
| 10 | Full SOC-in-a-box | planned |

---

## Repo Structure

```
.
├── configs/
│   ├── 99-cis.conf       # sysctl kernel hardening parameters
│   ├── jail.local        # fail2ban SSH jail config
│   └── sshd_config       # hardened SSH daemon config
├── docs/
│   └── rockysetup.md     # initial server setup notes
├── notes/
│   ├── issues.md         # all issues hit during the set up 
│   └── progress.md       # running log of what was done
├── screenshots/          # visual proof of work
├── scripts/
│   └── cis-audit.sh      # custom CIS Level 1 audit script
└── README.md
```

---

## What's in the scripts

### cis-audit.sh
a bash script that audits the Rocky server against CIS Level 1 benchmark controls and outputs a pass/fail report. covers SSH config, password policies, file permissions, kernel parameters, unnecessary services, SELinux, firewall, and auditd.

run it with:
```bash
sudo bash scripts/cis-audit.sh
```

save a report:
```bash
sudo bash scripts/cis-audit.sh | tee reports/audit-report.txt
```

---

## References

- Rocky Linux docs: https://docs.rockylinux.org
- CIS Benchmarks: https://cisecurity.org/benchmark/red_hat_linux
- firewalld docs: https://firewalld.org/documentation
- fail2ban wiki: https://github.com/fail2ban/fail2ban/wiki
- SELinux on RHEL: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/using_selinux


accidental format, proj down

