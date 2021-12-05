#!/bin/sh

srcpath=$(realpath "$1")
node="$2"
outputpath=$(realpath "$3")

cd ~/src/mweb
echo "(use-stage '(\"0\" \"1\") \"$srcpath\" \"$node\" \"$outputpath\")" \
	| scheme --load stage0.scm

