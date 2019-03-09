all: deb

fetch:
	@mkdir -p root/usr/bin root/usr/bin
	@cp /usr/bin/crsh root/usr/bin
	@cp /usr/bin/crsh-fdisk root/usr/bin
	@cp /usr/bin/crsh-helper.sh root/usr/bin
	@cp /usr/bin/crsh-resize.sh root/usr/bin

deb:
	dpkg-deb -b root .

clean:
	@rm -f *.xz *.deb
	@rm -f root/usr/bin/crsh root/usr/bin/crsh-fdisk root/usr/bin/crsh-helper.sh root/usr/bin/crsh-resize.sh
	@mkdir -p root/usr/bin

.PHONY: deb
