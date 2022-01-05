LIT = stage-1.mw
BUILD_CMD = echo "" | mit-scheme --no-init-file --load stage-0

classic:
	ln -sf classic.mw mweb.mw
	${BUILD_CMD}
clean:
	rm -rf ${LIT:.mw=.scm} mweb.*
