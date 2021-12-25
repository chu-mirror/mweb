#!/bin/sh

if [ $# -ne 4 ]; then
	echo "usage: mweb <stage> <mweb file> <node name> <output file>"
	exit 1
fi

stage="$1"
shift 1

srcpath=$(realpath "$1")
node="$2"
outputpath=$(realpath "$3")

used_stages='"0"'
case $stage in
'1') used_stages='"0" "1"';;
esac

cd "MWEBPATH"
echo "(use-stage '($used_stages) \"$srcpath\" \"$node\" \"$outputpath\")" \
	| scheme --load stage-0.scm

