.POSIX:
CC     ?= cc
PREFIX ?= /usr/local
CFLAGS ?= -O2

.PHONY: all clean check install

all:
	${CC} -std=c99 -pedantic -Wall -D_GNU_SOURCE=1 ${CFLAGS} ${LDFLAGS} -o grep *.c

clean:
	rm -f grep egrep fgrep rgrep

check: all
	@./test.zsh ${CHECK}

install:
	install -Dm755 grep ${DESTDIR}${PREFIX}/bin/grep
	cd ${DESTDIR}${PREFIX}/bin && ( \
		ln -sf grep  egrep     ;\
		ln -sf grep  fgrep     ;\
		ln -sf grep  rgrep     ;\
	)

	install -Dm644 grep.1 ${DESTDIR}${PREFIX}/share/man/man1/grep.1
	cd ${DESTDIR}${PREFIX}/share/man/man1 && ( \
		ln -sf grep.1 egrep.1      ;\
		ln -sf grep.1 fgrep.1      ;\
		ln -sf grep.1 rgrep.1      ;\
	)

install-zgrep:
	install -Dm755 zgrep.sh ${DESTDIR}${PREFIX}/bin/zgrep
	cd ${DESTDIR}${PREFIX}/bin && ( \
		ln -sf zgrep zfgrep    ;\
		ln -sf zgrep zegrep    ;\
		ln -sf zgrep bzgrep    ;\
		ln -sf zgrep bzegrep   ;\
		ln -sf zgrep bzfgrep   ;\
		ln -sf zgrep lzgrep    ;\
		ln -sf zgrep lzegrep   ;\
		ln -sf zgrep lzfgrep   ;\
		ln -sf zgrep xzgrep    ;\
		ln -sf zgrep xzegrep   ;\
		ln -sf zgrep xzfgrep   ;\
		ln -sf zgrep zstdgrep  ;\
		ln -sf zgrep zstdegrep ;\
		ln -sf zgrep zstdfgrep ;\
	)

	install -Dm644 zgrep.1 ${DESTDIR}${PREFIX}/share/man/man1/zgrep.1
	cd ${DESTDIR}${PREFIX}/share/man/man1 && ( \
		ln -sf zgrep.1 zfgrep.1    ;\
		ln -sf zgrep.1 zegrep.1    ;\
		ln -sf zgrep.1 bzgrep.1    ;\
		ln -sf zgrep.1 bzegrep.1   ;\
		ln -sf zgrep.1 bzfgrep.1   ;\
		ln -sf zgrep.1 lzgrep.1    ;\
		ln -sf zgrep.1 lzegrep.1   ;\
		ln -sf zgrep.1 lzfgrep.1   ;\
		ln -sf zgrep.1 xzgrep.1    ;\
		ln -sf zgrep.1 xzegrep.1   ;\
		ln -sf zgrep.1 xzfgrep.1   ;\
		ln -sf zgrep.1 zstdgrep.1  ;\
		ln -sf zgrep.1 zstdegrep.1 ;\
		ln -sf zgrep.1 zstdfgrep.1 ;\
	)
