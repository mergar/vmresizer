#!/bin/sh

# fatal error. Print message then quit with exitval
err() {
	exitval=$1
	shift
	echo "$*"
	exit $exitval
}

get_nic()
{
	mynic=$( for i in $( ls -1 /sys/class/net/ ); do
	[ $i = "lo" ] && continue
		echo $i
	done )

	echo $mynic
}

configure_net()
{
	local mynic

	mynic=$( get_nic )

	[ -z "${mynic}" ] && return 0

	local ip4_addr="10.0.0.41"
	local netmask="255.255.255.0"
	local gw="10.0.0.1"

	if [ ! -f /etc/crsh/network.txt ]; then
		echo "no /etc/crsh/network.txt"
		exit 0
	fi

	. /etc/crsh/network.txt

	rm -f /etc/network/interfaces.d/*.conf

	case "${ip4_addr}" in
		[Dd][Hh][Cc][Pp])
			cat > /etc/network/interfaces.d/${mynic}.conf <<EOF
# The primary network interface
allow-hotplug ${mynic}
iface ${mynic} inet dhcp
EOF
			;;
		[Rr][Ee][Aa][Ll][Dd][Hh][Cc][Pp])
			cat > /etc/network/interfaces.d/${mynic}.conf <<EOF
# The primary network interface
allow-hotplug ${mynic}
iface ${mynic} inet dhcp
EOF
			;;
		*)
			cat > /etc/network/interfaces.d/${mynic}.conf <<EOF
# The primary network interface
allow-hotplug ${mynic}

auto $mynic
iface $mynic inet static
	address ${ip4_addr}
	netmask ${netmask}
	gateway ${gw}
	# dns-* options are implemented by the resolvconf package, if installed
	dns-nameservers 8.8.8.8
	dns-search my.domain
EOF
			;;
	esac

	ip addr flush dev ${mynic}
	ifdown ${mynic}
	ifup ${mynic}
}


configure_authkey()
{

	local homedir
	local sshdir
	local authkey_file

	[ -z "${authkey}" ] && return 0

	homedir=$( grep "^${authuser}:" /etc/passwd 2>/dev/null | cut -d":" -f6 2>/dev/null )

	if [ ! -d "${homedir}" ]; then
		echo "No such user or wrong realpath homedir for ${authuser}: ${homedir}"
		return 1
	fi

	sshdir="${homedir}/.ssh"
	authkey_file="${homedir}/.ssh/authorized_keys"

	if [ ! -d "${sshdir}" ]; then
		mkdir -p ${sshdir}
		chown ${authuser} ${sshdir}
		chmod 0700 ${sshdir}
	fi

	chown ${authuser} ${sshdir}
	echo "${authkey}" > ${authkey_file}
	chown ${authuser} ${authkey_file}
}


# MAIN
tmp="/tmp/crsh.tmp"
oldmd=""

[ -f "${tmp}.md5" ] && oldmd=$( cat ${tmp}.md5 )
[ -r ${tmp} ] && rm -f ${tmp}

for i in $( lsblk -o NAME,TYPE |grep disk$ |awk '{printf " "$1}' ); do
	printf "Processing $i ..." >> /var/log/crsh.log
	/usr/bin/crsh /dev/${i} ${tmp} >> /var/log/crsh.log 2>&1
done

if [ -f ${tmp} ]; then
	newmd=$( md5sum ${tmp} |awk '{printf $1}' )

	if [ "${newmd}" != "${oldmd}" ]; then
		printf "${newmd}" > ${tmp}.md5
		#exec /bin/sh ${tmp} > /dev/null 2>&1
		/bin/sh ${tmp} > /dev/null 2>&1
	fi
fi

[ ! -f /etc/crsh/network.txt ] && err 1 "no /etc/crsh/network.txt"
. /etc/crsh/network.txt

configure_net
[ -n "${authkey}" ] && configure_authkey
