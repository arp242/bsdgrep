#!/bin/sh

set -eu

for f in file.c grep.1 grep.c grep.h queue.c util.c zgrep.sh zgrep.1; do
	curl -sLO https://raw.githubusercontent.com/freebsd/freebsd-src/main/usr.bin/grep/$f
done
for f in fts.c fts.h; do
	curl -sLO https://raw.githubusercontent.com/void-linux/musl-fts/master/$f
done
curl -sLO 'https://gitlab.freedesktop.org/libbsd/libbsd/-/raw/main/src/progname.c?ref_type=heads'

sed -Ei '/^#include <(bzlib|zlib|sys\/cdefs|sys\/queue)\.h>$/d' *.c *.h
sed -i  's/#include <fts.h>/#include "fts.h"/' *.c
sed -i  '/grep\.h/a #include "freebsd.h"' file.c grep.c queue.c util.c
sed -i '/^#include "config\.h"$/d; s/^#if !defined(HAVE_DECL_MAX).*/#ifndef MAX/' fts.c
