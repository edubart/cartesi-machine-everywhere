#define LUA_IMPL
#include <minilua.h>

#ifdef __wasm__
/* Fix missing syscall errors when running with Wasmer/Wasmtime */
#include <sys/select.h>
#include <errno.h>
extern "C" FILE *freopen(const char *__restrict, const char *__restrict, FILE *__restrict) { errno=EOPNOTSUPP; return NULL; }
extern "C" int rename(const char *, const char *) { errno=EOPNOTSUPP; return -1; }
extern "C" int remove(const char *) { errno=EOPNOTSUPP; return -1; }
extern "C" int rmdir(const char *) { errno=EOPNOTSUPP; return -1; }
extern "C" int unlink(const char *) { errno=EOPNOTSUPP; return -1; }
extern "C" int unlinkat(int, const char *, int) { errno=EOPNOTSUPP; return -1; }
extern "C" int system(const char *) { errno=EOPNOTSUPP; return -1; }
extern "C" int select(int, fd_set *__restrict, fd_set *__restrict, fd_set *__restrict, struct timeval *__restrict) { errno=EOPNOTSUPP; return -1; }
extern "C" FILE *tmpfile(void) { errno=EOPNOTSUPP; return NULL; }
#endif
