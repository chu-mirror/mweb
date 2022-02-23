SRC = stage-1.scm mweb-proto.scm mweb-proto

proto:
	echo "" | mit-scheme --no-init-file --load stage-0

clean:
	rm -rf ${SRC}
