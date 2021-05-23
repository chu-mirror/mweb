# require GNU make

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
	@${RM} ${LIT:.w=.toc} ${LIT:.w=.log} \
		${LIT:.w=.scn} ${LIT:.w=.idx}
