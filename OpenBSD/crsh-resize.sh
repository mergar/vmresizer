#!/bin/sh
# eg: -r 192.168.0.100:3260,257 -t iqn.192.168.0.109:target0 -s 10
#-r ${iremote} -t ${itarget} -s ${size} -l $login -p $pw -i $ip4_addr -g $gw

# fatal error. Print message then quit with exitval
err() {
	exitval=$1
	shift
	echo "$*"
	exit $exitval
}

trap "iscsictl -Ra" HUP INT ABRT BUS TERM EXIT

zfs=0

while getopts "a:bh:r:t:s:l:p:i:g:z:" opt; do
	case "$opt" in
		a) authkey="${OPTARG}" ;;
		b) bootstrap=1 ;;
		h) host_hostname="${OPTARG}" ;;
		r) iremote="${OPTARG}" ;;
		t) itarget="${OPTARG}" ;;
		s) size="${OPTARG}" ;;
		l) login="${OPTARG}" ;;
		p) pw="${OPTARG}" ;;
		i) ip4_addr="${OPTARG}" ;;
		g) gw="${OPTARG}" ;;
		z) zfs="${OPTARG}" ;;
	esac
	shift $(($OPTIND - 1))
done


[ -z "${bootstrap}" ] && bootstrap=0	# bootstrap=1 for store disk on boot stage
datasize=$(( size - 1 ))
config="/usr/local/etc/resizer_disk_local.txt"

usage()
{
	echo "$0 -r iremote -t itarget -s size_in_GB"
	echo "eg: -r 192.168.0.100:3260,257 -t iqn.192.168.0.109:target0 -s 10"
	exit 1
}

bootstrap()
{
	local mydisk=$( sysctl -qn kern.disks )
	[ ! -d /usr/local/etc ] && mkdir /usr/local/etc
	echo "local_disk=\"${mydisk}\"" > ${config}
}

detect_disk()
{
	. ${config}
	local notfound

	local mydisk=$( sysctl -qn kern.disks )

	for x in ${mydisk}; do
		notfound=0
		for y in ${local_disk}; do
			[ "${x}" = "${y}" ] && notfound=1 && continue
		done
		[ ${notfound} -eq 0 ] && printf "/dev/${x}" && break
	done
}

if [ ${bootstrap} -eq 1 ]; then
	bootstrap
	exit 0
fi

[ ! -f ${config} ] && err 1 "No config: ${config}. Please run init with -b on boot stage"

if [ -z "${size}" ]; then
	usage
	exit 1
fi

guest_disk=$( detect_disk )

[ -z "${guest_disk}" ] && err 1 "Guest disk not found"
[ ! -c ${guest_disk} ] && err 1 "No ${guest_disk} device"

echo ":: disk found: ${guest_disk}"
echo "ufs $datasize"

sleep 3

set -o xtrace
set -o errexit

for attempt in 1 2 3 4 5; do
	echo "gpart recover ${guest_disk}"
	gpart recover ${guest_disk}
	[ $? -eq 0 ] && break
	echo "Attempt ${attempt}"
	sleep 1
done

echo "RDY"

if [ ${zfs} -eq 1 ]; then
	trap "zpool export zroot" HUP INT ABRT BUS TERM EXIT
	set +o xtrace
	zpool import -f -R /mnt zroot
	# /dev/da4p4 << ZPOOL
	# loss 1 G?
	datasize=$(( datasize - 1 ))
	echo "gpart resize -i 4 -s ${datasize}g ${guest_disk}"
	gpart resize -i 4 -s ${datasize}g ${guest_disk}
	zpool online -e zroot /dev/da0p4
	zfs mount -a
	zfs mount zroot/ROOT/default
else
	set +o xtrace
	gpart delete -i 3 ${guest_disk}
	fsck_ufs -y ${guest_disk}p2
	gpart resize -i 2 -s ${datasize}g ${guest_disk}
	growfs -y ${guest_disk}p2
	gpart add -t freebsd-swap ${guest_disk}
	/sbin/mount ${guest_disk}p2 /mnt
fi
set -o xtrace
set -o errexit
echo "MOUNTED"

case "${ip4_addr}" in
	[Dd][Hh][Cc][Pp])
		echo "SET DHCP"	
		# vtnet0 hardcoded??
		sysrc -qf /mnt/etc/rc.conf ifconfig_vtnet0="DHCP"
		gw=0
		;;
	[Rr][Ee][Aa][Ll][Dd][Hh][Cc][Pp])
		echo "SET DHCP"	
		# vtnet0 hardcoded??
		sysrc -qf /mnt/etc/rc.conf ifconfig_vtnet0="DHCP"
		gw=0
		;;
	*)
		if [ "${ip4_addr}" != "0" ]; then
			echo "SET IP $ip4_addr"	
			# vtnet0 hardcoded??
			sysrc -qf /mnt/etc/rc.conf ifconfig_vtnet0="${ip4_addr}"
		else
			echo "SET DHCP"	
			# vtnet0 hardcoded??
			sysrc -qf /mnt/etc/rc.conf ifconfig_vtnet0="DHCP"
			gw=0
		fi
esac

if [ "${gw}" != "0" ]; then
	sysrc -qf /mnt/etc/rc.conf defaultrouter="${gw}"
else
	sysrc -qf /mnt/etc/rc.conf defaultrouter="NO"
fi

if [ "${host_hostname}" != "0" ]; then
	sysrc -qf /mnt/etc/rc.conf hostname="${host_hostname}"
fi

if [ "${login}" != "0" ]; then

	mount -t devfs devfs /mnt/dev

	chroot /mnt /bin/sh <<EOF
	/usr/sbin/pw useradd ${login} -m -G wheel -s /bin/csh
	if [ -n "${pw}" -a "${pw}" != "0" ]; then
		echo "${pw}" |/usr/sbin/pw mod user ${login} -h 0 -
		echo "${pw}" |/usr/sbin/pw mod user root -h 0 -
	fi
EOF

	if [ "${authkey}" != "0" -a -f "${authkey}" ]; then
		mkdir -p /mnt/home/${login}/.ssh
		cp -a ${authkey} /mnt/home/${login}/.ssh/authorized_keys
		chroot /mnt <<EOF
			chown -R ${login}:${login} /home/${login}
EOF
	fi

	umount /mnt/dev
fi

rm -f /mnt/etc/ssh/ssh_host_*
truncate -s0 /mnt/var/log/*

if [ ${zfs} -eq 1 ]; then
	zfs unmount zroot/ROOT/default
	zfs unmount -a
	umount /mnt ||true
	trap "date" HUP INT ABRT BUS TERM EXIT
	zpool export zroot
else
	umount /mnt
fi

sync
