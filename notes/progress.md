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

# PHASE 1 COMPLETE

