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
	mynic=$( for i in $( /sbin/ifconfig -l ); do
	[ $i = "lo0" ] && continue
		echo $i
	done )

	echo $mynic

}


configure_net()
{
	local mynic

	mynic=$( get_nic )

	[ -z "${mynic}" ] && return 0

	if [ -z "${ip4_addr}" ]; then
			echo "No ip4_addr"
			return 1
	fi

	case "${ip4_addr}" in
		[Rr][Ee][Aa][Ll][Dd][Hh][Cc][Pp])
			sysrc ifconfig_${mynic}="DHCP"
			sysrc defaultrouter="NO"
			#/usr/sbin/service dhclient stop
			# > /dev/null 2>&1
			#/usr/sbin/service dhclient start
			# > /dev/null 2>&1
			/sbin/dhclient ${mynic}
			# > /dev/null 2>&1
			;;
		[Dd][Hh][Cc][Pp])
			sysrc ifconfig_${mynic}="DHCP"
			sysrc defaultrouter="NO"
			#/usr/sbin/service dhclient stop
			# > /dev/null 2>&1
			#/usr/sbin/service dhclient start
			# > /dev/null 2>&1
			/sbin/dhclient ${mynic}
			# > /dev/null 2>&1
			;;
		*)
			[ -z "${netmask}" ] && netmask="255.255.255.0"
			[ -z "${gw}" ] && echo "No gw" && return 1
			sysrc ifconfig_${mynic}="inet ${ip4_addr} netmask ${netmask}"
			sysrc defaultrouter="${gw}"
			/usr/sbin/service netif stop > /dev/null 2>&1
			/usr/sbin/service netif start > /dev/null 2>&1
			/usr/sbin/service routing stop > /dev/null 2>&1
			/usr/sbin/service routing start > /dev/null 2>&1
			;;
	esac
}

configure_authkey()
{

	local homedir
	local sshdir
	local authkey_file

	[ -z "${authkey}" ] && return 0

	homedir=$( pw user show ${authuser} |cut -d : -f 9 )

	if [ ! -d "${homedir}" ]; then
		echo "No such user or wrong realpath homedir for ${authuser}"
		return 0
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

[ -f "${tmp}.md5" ] && oldmd=$( /bin/cat ${tmp}.md5 )
[ -r ${tmp} ] && /bin/rm -f ${tmp}

for i in $( /sbin/sysctl -n kern.disks ); do
	printf "Processing $i ..." >> /var/log/crsh.log
	/usr/bin/crsh /dev/${i} ${tmp} >> /var/log/crsh.log 2>&1
done

if [ -f ${tmp} ]; then
	newmd=$( md5 -q ${tmp} )

	if [ "${newmd}" != "${oldmd}" ]; then
		printf "${newmd}" > ${tmp}.md5
		#exec /bin/sh ${tmp} > /dev/null 2>&1
		/bin/sh ${tmp} > /dev/null 2>&1
	fi
fi

[ ! -f /etc/crsh/network.txt ] && err 0 "no /etc/crsh/network.txt"
. /etc/crsh/network.txt

configure_net
[ -n "${authkey}" ] && configure_authkey
