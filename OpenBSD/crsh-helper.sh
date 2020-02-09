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
	local _nic_list=$( ifconfig |grep -E "^[aA-zZ]+" |cut -d : -f 1 | xargs )
	local _mynic i

	for i in ${_nic_list}; do
		case "${i}" in
			lo0|enc*|pflog*)
				continue
				;;
			*)
				_mynic="${i}"
				;;
		esac
	done

	echo ${_mynic}

}


configure_net()
{
	local mynic

	mynic=$( get_nic )

	if [ -z "${mynic}" ]; then
		echo "No nic"
		return 0
	fi

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
			#[ -z "${netmask}" ] && netmask="255.255.255.0"
			netmask="0xffffff00"
			
			[ -z "${gw}" ] && echo "No gw" && return 1
			echo "inet ${ip4_addr} ${netmask}" > /etc/hostname.${mynic}
			echo "${gw}" > /etc/mygate
			#/usr/sbin/service netif stop > /dev/null 2>&1
			#/usr/sbin/service netif start > /dev/null 2>&1
			#/usr/sbin/service routing stop > /dev/null 2>&1
			#/usr/sbin/service routing start > /dev/null 2>&1
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
[ ! -d /etc/crsh ] && mkdir /etc/crsh
tmp="/tmp/crsh.tmp"
oldmd=""

[ -f "${tmp}.md5" ] && oldmd=$( /bin/cat ${tmp}.md5 )
[ -r ${tmp} ] && /bin/rm -f ${tmp}

disk_list=$( sysctl -n hw.disknames | tr "," "\n" | while read _dev; do
	p1=${_dev%%:*}
	p2=${_dev##*:}
	printf "${p1} "
done )

#echo "${disk_list}"

for i in ${disk_list}; do
	echo "Processing $i ..." >> /var/log/crsh.log
	_dev=$( file -s /dev/sd* |grep "Bourne shell script text" |cut -d : -f1 |awk '{printf $1}' )
	[ -z "${_dev}" ] && continue
	echo "Found: ${_dev} ..." >> /var/log/crsh.log
	/usr/bin/crsh ${_dev} ${tmp} >> /var/log/crsh.log 2>&1
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
