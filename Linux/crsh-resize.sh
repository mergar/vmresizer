#!/bin/sh
#192.168.0.100:3260,257 iqn.192.168.0.109:target0 10G
#iremote="${1}"
#itarget="${2}"
#size="${3}"

# fatal error. Print message then quit with exitval
err() {
	exitval=$1
	shift
	echo "$*"
	exit $exitval
}

usage()
{
	echo "$0 -r iremote -t itarget -s size_in_GB"
	echo "eg: -r 192.168.0.100:3260,257 -t iqn.192.168.0.109:target0 -s 10"
	exit 1
}

bootstrap()
{
	local mydisk
	mydisk=$( lsblk -o KNAME,TYPE |grep disk$ |awk '{printf $1" "}' )
	echo "local_disk=\"${mydisk}\"" > ${config}
}

detect_disk()
{
	. ${config}
	local notfound

	local mydisk
	mydisk=$( lsblk -o KNAME,TYPE |grep disk$ |awk '{printf $1" "}' )

	for x in ${mydisk}; do
		notfound=0
		for y in ${local_disk}; do
			[ "${x}" = "${y}" ] && notfound=1 && continue
		done
		[ ${notfound} -eq 0 ] && printf "/dev/${x}" && break
	done
}

mask2cdr ()
{
	# Assumes there's no "255." after a non-255 byte in the mask
	local x=${1##*255.}
	set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
	x=${1%%$3*}
	echo $(( $2 + (${#x}/4) ))
}

cdr2mask ()
{
	# Number of args to shift, 255..255, first non-255 byte, zeroes
	set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
	[ $1 -gt 1 ] && shift $1 || shift
	echo ${1-0}.${2-0}.${3-0}.${4-0}
}


### MAIN
while getopts "a:bh:r:t:s:l:p:i:g:" opt; do
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
	esac
	shift $(($OPTIND - 1))
done


[ -z "${bootstrap}" ] && bootstrap=0    # bootstrap=1 for store disk on boot stage
datasize=$(( size - 1 ))
config="/etc/resizer_disk_local.txt"

[ -z "${login}" ] && login="0"

if [ ${bootstrap} -eq 1 ]; then
	bootstrap
	exit 0
fi

[ ! -f ${config} ] && err 1 "No config: ${config}. Please run init with -b on boot stage"

if [ -z "${size}" ]; then
	usage
	exit 1
fi

trap "iscsiadm --m node -T ${itarget} --portal ${iremote} -u" HUP INT ABRT BUS TERM EXIT

echo ":: iscsadm attach"
iscsiadm --m node -T ${itarget} --portal ${iremote} --login
sleep 3

guest_disk=$( detect_disk )

[ -z "${guest_disk}" ] && err 1 "Guest disk not found"
[ ! -b ${guest_disk} ] && err 1 "No block special device: ${guest_disk}"

echo ":: Guest disk found: ${guest_disk}"
echo ":: GROW TO: ${size} GB SIZE"

/usr/bin/crsh-fdisk ${guest_disk} ${size}

### MODIFY AREA
mount ${guest_disk}2 /mnt

[ "${ip4_addr}" = "DHCP" ] && ip4_addr="0"
[ "${ip4_addr}" = "REALDHCP" ] && ip4_addr="0"

if [ "${ip4_addr}" != "0" ]; then

	if [ $( echo ${ip4_addr} |grep "/" ) ]; then
		mynet=${ip4_addr%%/*}
		mycidr=${ip4_addr##*/}
	else
		mynet="${ip4_addr}"
		mycidr="24"
	fi

	echo "MYNET : ${mynet} "

	mymask=$( cdr2mask $mycidr )
	[ -z "${mymask}" ] && mymask="255.255.255.0"
	echo "SET IP $mynet $mymask"

[ ! -d /mnt/root/bin ] && mkdir /mnt/root/bin

cat > /mnt/root/bin/network.txt <<EOF
ip4_addr="${mynet}"
netmask="${mymask}"
gw="${gw}"
EOF
fi

if [ "${host_hostname}" != "0" ]; then
	echo "${host_hostname}" > /mnt/etc/hostname
fi

if [ "${login}" != "0" ]; then

#        mount -t devfs devfs /mnt/dev

	chroot /mnt /bin/sh <<EOF
	userdel ${login} >/dev/null 2>&1||true
	groupdel ${login} >/dev/null 2>&1||true
	rm -rf /mnt/home/${login}
#	groupadd ${login}
	useradd -G sudo ${login} -s /bin/bash
	[ ! -d /mnt/home/${login} ] && mkdir -p /mnt/home/${login}
	chmod 0770 /mnt/home/${login}
	chown ${login} /mnt/home/${login}
EOF

if [ "${pw}" != "0" ]; then
	chroot /mnt /bin/sh <<EOF
	passwd ${login} <<EOP
${pw}
${pw}
EOP
EOF
fi

	if [ ! -d /mnt/etc/sudoers.d ]; then
		mkdir -p /mnt/etc/sudoers.d
		chmod 0750 /mnt/etc/sudoers.d
	fi

	cat > /mnt/etc/sudoers.d/${login} <<EOF
${login}   ALL=(ALL) NOPASSWD: ALL
EOF

	chmod 0400 /mnt/etc/sudoers.d/${login}

	if [ "${authkey}" != "0" -a -f "${authkey}" ]; then
		mkdir -p /mnt/home/${login}/.ssh
		cp -a ${authkey} /mnt/home/${login}/.ssh/authorized_keys
		chroot /mnt <<EOF
chown -R ${login}:${login} /home/${login}
EOF
	fi
#        umount /mnt/dev
fi

# not for Linux
#rm -f /mnt/etc/ssh/ssh_host_*

truncate -s0 /mnt/var/log/* > /dev/null 2>&1
cd /

umount /mnt
####### modify area

sync
echo "UNMOUNT"
