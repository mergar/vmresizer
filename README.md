Микросервис по выполнению ресайза партишена Linux и FreeBSD.

Версия 1:

- набор костылей-лишь-бы-работало: поддержка UFS и ext4

TODO :

1) Делать в виде очереди задачь (AMQP, KAFKA)
2) Автоматически понимать какой дистр и FS
3) поддержка ZFS/ZVOL и LVM.

Linux requirenemnts:

Have /etc/network/interfaces without physical ifaces, e.g:

--
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
--

Due to crsh manage entries in in /etc/network/interfaces.d/*.conf

Со стороны гипервизора:

--
/bin/cat > ${system_dsk_path} <<CEOF
#!/bin/sh
cat > /etc/crsh/network.txt <<EOF
ip4_addr="${orig_ip4_addr}"
netmask="${orig_mask}"
gw="${orig_gw}"
nameserver="${nameserver}"
authuser="${authuser}"
authkey="${authkey}"
EOF
CEOF

/usr/bin/truncate -s1m ${system_dsk_path}
--
