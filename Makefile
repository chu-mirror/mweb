# require GNU make

CFLAGS = -g

LIT = mweb.w
DOC = ${LIT:.w=.pdf}
ALL = ${LIT:.w=}

PREFIX = /usr/local
BINDIR = ${PREFIX}/bin

.SUFFIXES: .pdf
.tex.pdf:
	pdftex $<

all: ${ALL}

doc: ${DOC}

ex: all
	cd examples; make

clean:
	${RM} ${DOC} ${ALL}
	@${RM} ${LIT:.w=.toc} ${LIT:.w=.log} ${LIT:.w=.tex} \
		${LIT:.w=.scn} ${LIT:.w=.idx} ${LIT:.w=.c}
	@cd examples; make clean

install:
	cp mweb ${BINDIR}
