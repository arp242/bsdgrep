#!/bin/sh

set -eu

IFS='
'

# Get all files except the Makefile
# https://raw.githubusercontent.com/freebsd/freebsd-src/main/usr.bin/grep/Makefile.depend
for f in $(curl -s 'https://github.com/freebsd/freebsd-src/tree/main/usr.bin/grep' |
	grep -Eo 'href="/freebsd/freebsd-src/blob/main/usr\.bin/grep/[^M].*?"');
do
	f=$(basename "${f%\"}")
	echo "$f"
	curl -s "https://raw.githubusercontent.com/freebsd/freebsd-src/main/usr.bin/grep/$f" > "$f"
done

sed -i '/^__FBSDID/i #include "freebsd.h"' *.c
