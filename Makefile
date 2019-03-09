PREFIX?=/usr
CC?=cc
STRIP=strip
RM=rm
CP=cp
MAKE=make
INSTALL=install
MKDIR=rmdir
KERNEL!=uname -s

all:	crsh

clean:
	${RM} -f crsh

crsh:
	${CC} crsh.c -o crsh && ${STRIP} crsh

install:
	${INSTALL} crsh ${PREFIX}/bin/crsh
	${INSTALL} $(KERNEL)/crsh-helper.sh ${PREFIX}/bin/crsh-helper.sh
	${INSTALL} $(KERNEL)/crsh-resize.sh ${PREFIX}/bin/crsh-resize.sh
	test -d /etc/crsh || mkdir /etc/crsh
	# Make bootstrap
	${PREFIX}/bin/crsh-resize.sh -b
	# os-specific install
	$(KERNEL)/install.sh
