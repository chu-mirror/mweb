ALL = mweb

all: ${ALL}

mweb: mweb.sh
	sed -e 's|MWEBPATH|'$$(pwd)'|g' $< > $@
	chmod +x $@

