SRC = stage-1.scm mweb-proto.scm mweb-proto
PREFIX = /usr/local

proto:
	echo "" | mit-scheme --no-init-file --load stage-0
	chmod +x mweb-proto

install:
	[ -d ~/.scheme-lib ] || mkdir ~/.scheme-lib
	cp -f mweb-proto.scm -t ~/.scheme-lib
	sudo cp -f mweb-proto -t ${PREFIX}/bin

uninstall:
	rm -f ~/.scheme-lib/mweb-proto.scm
	sudo rm -f ${PREFEX}/bin/mweb-proto

clean:
	rm -rf ${SRC} mweb-lib *.log *.pdf
