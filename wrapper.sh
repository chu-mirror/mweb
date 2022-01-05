#!/bin/sh

if [ $# -ne 3 ]; then
	echo "usage: mweb <mweb file> <node name> <output file>"
	exit 1
fi

srcpath=$(realpath "$1")
node="$2"
outputpath=$(realpath "$3")

cd ~/.scheme-lib
echo "(put-contents \"$outputpath\" (tangle \"$srcpath\" \"$node\"))" \
	| scheme --load mweb.scm

