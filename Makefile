LIT = stage-1.mw
BUILD_CMD = echo "" | mit-scheme --no-init-file --load stage-0

mweb-prototype.scm:
	mweb mweb-proto.mw "mweb prototype" mweb-proto.scm

classic:
	ln -sf classic.mw mweb.mw
	${BUILD_CMD}
clean:
	rm -rf ${LIT:.mw=.scm} mweb.*
