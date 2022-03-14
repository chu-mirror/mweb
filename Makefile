SRC = stage-1.scm mweb-proto.scm mweb-proto
PREFIX = ~/.local

proto:
	echo "" | mit-scheme --no-init-file --load stage-0
	chmod +x mweb-proto

install:
	cp -f mweb-proto.scm -t ~/.scheme-lib
	cp -f mweb-proto -t ${PREFIX}/bin

clean:
	rm -rf ${SRC} mweb-lib
