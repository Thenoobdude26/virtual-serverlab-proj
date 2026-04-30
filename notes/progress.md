# PHASE 1
Rocky server installed and initialized.
both adapters detected.
ping to 8.8.8.8 succesful, 5 packets transmitted, 5 recieved , 0% packet loss
ping to 192.168.56.1 succesful, 4 packets transmitted, 4 recieved 0% packet lost

setting server to static ip on the host only adapter using command `nmcli con mod enp0s3 ipv4.addresses 192.168.56.10/24 ipv4.method manual`
slight issue, typo detected `enp0s3p` typed instead of `enp0s3`
connection activated using `nmcli con up enp0s3`

now installing basic network tools `dnf install -y vim curl wget net-tools bash-completion`
already installed so just an update
checked if firewall as all good, enabled and running.


# Phase 2: SSH hardening

ssh runs on prt 22, in this phase we secure it from hackers closing the leaks and gaps. core principle sbeing applied are:
- SSH keys
- least privilage or no direct root login
- Reduced attack surface, limiting who can connect

Generating SSH key on out host machine using `ssh-keygen -t ed25519 -C "lab-key"`
here we create a private key that i keep to myself and a public key that is what i'll be putting into the server
- ~/.ssh/id_ed25519 (private)
- ~/.ss/id_ed25519.pub (public)

# **ISSUE!!** 
static ip given to  enp0s3(NAT) instead of enp0s8(host only).
sovled by removing the static ip from enp0s3 and putting it back on dhcp, coz well nat need dhcp
``sudo nmcli con mod enp0s3 ipv4.method auto ipv4.addresses ""'``
``sudo nmcli con up enp0s3``

then creating a proper profile on the host only adapter enp0s8
``sudo nmcli con add type ethernet ifname enp0s8 con-name host-only``
``sudo nmcli con mod host-only ipv4.addresses 192.168.56.10/24 ipv4.method manual``
``sudo nmcli con upp host-only``

a quick `ip a` to check if correct and. . .<cue drum roll> 
all good.

## continuing
# PHASE 1 COMPLETE