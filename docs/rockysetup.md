# Rocky Server Setup Reference

## System Info
- OS: Rocky Linux 9.7 (Blue Onyx)
- Kernel: 5.14.0-611.47.1.el9_7.x86_64
- Hostname: AllSeeingEye
- User: overlord

## Network
| Adapter | Interface | Type | IP |
|---|---|---|---|
| Adapter 1 | enp0s3 | NAT (internet) | 10.0.2.15 (DHCP) |
| Adapter 2 | enp0s8 | Host-Only (lab) | 192.168.56.10 (static) |

## Services Running
| Service | Status | Notes |
|---|---|---|
| sshd | active | port 2222, key auth only |
| firewalld | active | public/internal zones |
| fail2ban | active | SSH jail, 3 retries, 1h ban |
| auditd | active | default rules |
| SELinux | enforcing | — |

## Snapshot History
| Snapshot | Description |
|---|---|
| Level1-clean-base | fresh install, network configured |
| Level2-ssh-hardened | SSH locked down to port 2222, key auth |
| Level3-firewall-fail2ban | zones assigned, fail2ban active |
| Level4-cis-audit | CIS audit script, 22/22 pass |