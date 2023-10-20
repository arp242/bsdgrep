#ifndef	_FREEBSD_H_
#define	_FREEBSD_H_

const char * getprogname(void);

// https://github.com/freebsd/freebsd-src/blob/b9f04b3/sys/sys/cdefs.h#L581
// Empty anyway, so no need to embed it.
#ifndef	__FBSDID
#define	__FBSDID(s)	struct __hack
#endif

#ifndef __DECONST
#include <stdint.h>
#define __DECONST(type, var)    ((type)(uintptr_t)(const void *)(var))
#endif

// https://github.com/freebsd/freebsd-src/blob/b500c184/tools/build/cross-build/include/linux/limits.h
#ifndef OFF_MAX
#define OFF_MAX UINT64_MAX
#endif

// https://github.com/freebsd/freebsd-src/blob/098dbd7/lib/libc/sys/mmap.2#L233
#define MAP_NOCORE 0
#define MAP_NOSYNC 0

// https://github.com/freebsd/freebsd-src/blob/42b3884/include/regex.h#L100
#ifndef REG_STARTEND
#define REG_STARTEND 4
#endif

#endif
