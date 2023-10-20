#!/bin/sh

set -eu

for f in file.c grep.1 grep.c grep.h queue.c util.c zgrep.sh zgrep.1; do
	curl -sLO https://raw.githubusercontent.com/freebsd/freebsd-src/main/usr.bin/grep/$f
done

sed -Ei '/^#include <(bzlib|zlib|sys\/cdefs|sys\/queue)\.h>$/d' *.c *.h
sed -i  's/#include <fts.h>/#include "fts.h"/' *.c
sed -i  '/grep\.h/a #include "freebsd.h"' file.c grep.c queue.c util.c
