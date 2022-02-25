SRC = stage-1.scm mweb-proto.scm mweb-proto

proto:
	echo "" | mit-scheme --no-init-file --load stage-0
	chmod +x mweb-proto

lib: proto
	rm -rf mweb-lib
	mkdir mweb-lib
	cp mweb-proto.scm chapter/* -t mweb-lib

clean:
	rm -rf ${SRC} mweb-lib
