# require GNU make

CFLAGS = -g

LIT = mweb.w
DOC = ${LIT:.w=.pdf}
ALL = ${LIT:.w=}

.SUFFIXES: .pdf
.tex.pdf:
	pdftex $<

all: ${ALL}

doc: ${DOC}

clean:
	${RM} ${DOC} ${ALL}
	@${RM} ${LIT:.w=.toc} ${LIT:.w=.log} ${LIT:.w=.tex} \
		${LIT:.w=.scn} ${LIT:.w=.idx} ${LIT:.w=.c}
