#!/bin/sh
[ ! -d /usr/local/etc/rc.d ] && mkdir -p /usr/local/etc/rc.d
cp -a FreeBSD/rc.d/crsh-helper /usr/local/etc/rc.d/crsh-helper
rcctl enable crsh

