#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>

#include <lualib.h>
#include <lauxlib.h>
#include <lua.h>

#include "cartesi-gdbstub.lua.h"
#include "cartesi-machine.lua.h"
#include "cartesi-proof.lua.h"
#include "cartesi-util.lua.h"

#define MAX_PATH_LEN 4096
#ifdef _WIN32
#include <windows.h>
#include <shlwapi.h>
#define PATH_SEP "\\"
int setenv(const char *name, const char *value, int overwrite) {
  if (getenv(name)) {
    return -1;
  }
  char tmp[4096];
  snprintf(tmp, sizeof(tmp), "%s=%s", name, value);
  return _putenv(tmp);
}
char *dirname(char *path) {
  PathRemoveFileSpecA(path);
  return path;
}
#else
#include <unistd.h>
#include <libgen.h>
#define PATH_SEP "/"
#endif
#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

extern "C" int luaopen_cartesi(lua_State *L);
extern "C" int luaopen_cartesi_jsonrpc(lua_State *L);

static lua_State *globalL = NULL;

/*
** Create the 'arg' table, which stores all arguments from the
** command line ('argv'). It should be aligned so that, at index 0,
** it has 'argv[script]', which is the script name. The arguments
** to the script (everything after 'script') go to positive indices;
** other arguments (before the script name) go to negative indices.
*/
static void createargtable(lua_State *L, char **argv, int argc) {
  int i;
  lua_createtable(L, argc, argc);
  for (i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i);
  }
  lua_setglobal(L, "arg");
}

/*
** Message handler used to run all chunks
*/
static int msghandler (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {  /* is error object not a string? */
    if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
        lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
      return 1;  /* that is the message */
    else
      msg = lua_pushfstring(L, "(error object is a %s value)",
                               luaL_typename(L, 1));
  }
  luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
  return 1;  /* return the traceback */
}

#if defined(LUA_USE_POSIX) && !defined(__wasm__)   /* { */
/*
** Use 'sigaction' when available.
*/
static void setsignal (int sig, void (*handler)(int)) {
  struct sigaction sa;
  sa.sa_handler = handler;
  sa.sa_flags = 0;
  sigemptyset(&sa.sa_mask);  /* do not mask any signal */
  sigaction(sig, &sa, NULL);
}
#else
#define setsignal            signal
#endif

/*
** Hook set by signal function to stop the interpreter.
*/
static void lstop (lua_State *L, lua_Debug *ar) {
  (void)ar;  /* unused arg. */
  lua_sethook(L, NULL, 0, 0);  /* reset hook */
  luaL_error(L, "interrupted!");
}


/*
** Function to be called at a C signal. Because a C signal cannot
** just change a Lua state (as there is no proper synchronization),
** this function only sets a hook that, when called, will stop the
** interpreter.
*/
static void laction (int i) {
  int flag = LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT;
  setsignal(i, SIG_DFL); /* if another SIGINT happens, terminate process */
  lua_sethook(globalL, lstop, flag, 1);
}

/*
** Interface to 'lua_pcall', which sets appropriate message function
** and C-signal handler. Used to run all chunks.
*/
static int docall (lua_State *L, int narg, int nres) {
  int status;
  int base = lua_gettop(L) - narg;  /* function index */
  lua_pushcfunction(L, msghandler);  /* push message handler */
  lua_insert(L, base);  /* put it under function and args */
  globalL = L;  /* to be available to 'laction' */
  setsignal(SIGINT, laction);  /* set C-signal handler */
  status = lua_pcall(L, narg, nres, base);
  setsignal(SIGINT, SIG_DFL); /* reset C-signal handler */
  lua_remove(L, base);  /* remove message handler from the stack */
  return status;
}

/*
** Check whether 'status' is not OK and, if so, prints the error
** message on the top of the stack.
*/
static int report (lua_State *L, int status) {
  if (status != LUA_OK) {
    const char *msg = lua_tostring(L, -1);
    if (msg == NULL)
      msg = "(error message not a string)";
    lua_writestringerror("%s\n", msg);
    lua_pop(L, 1);  /* remove message */
    return EXIT_FAILURE;
  }
  return EXIT_SUCCESS;
}

/*
** Set package.loaded[name] to the top value on the stack.
*/
static void setpackageloaded (lua_State *L, const char *name) {
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "loaded");
  lua_remove(L, -2);
  lua_insert(L, -2);
  lua_setfield(L, -2, name);
  lua_pop(L, 1);
}

/*
** Load a buffer and call it
*/
static int dobuffercall (lua_State *L, unsigned char *buf, unsigned int len, const char *name, int nrets) {
  int status = luaL_loadbuffer(L, reinterpret_cast<const char*>(buf), len, name);
  if (status == LUA_OK) {
    status = docall(L, 0, nrets);
  }
  return status;
}

/*
** Load a buffer, call it and set package.loaded[pkgname] to the returning value.
*/
static int dobufferloadpackage (lua_State *L, unsigned char *buf, unsigned int len, const char *name, const char *pkgname) {
  int status = dobuffercall(L, buf, len, name, 1);
  if (status == LUA_OK) {
    setpackageloaded(L, pkgname);
  }
  return status;
}

/*
** Get current executable path.
*/
static size_t getexepath(char *path, size_t maxlen) {
  memset(path, 0, MAX_PATH_LEN);
#ifdef _WIN32
  GetModuleFileNameA(NULL, path, maxlen);
#elif __APPLE__
  uint32_t size = maxlen;
  _NSGetExecutablePath(path, &size);
#elif __linux
  if (readlink("/proc/self/exe", path, maxlen) < 0) {
    return -1;
  }
#endif
  return strnlen(path, maxlen);
}

/*
** Initialize CARTESI_IMAGES_PATH if unset.
*/
static void initimagespath() {
  char exepath[MAX_PATH_LEN];
  memset(exepath, 0, MAX_PATH_LEN);
  if (getexepath(exepath, MAX_PATH_LEN) <= 0) {
    return;
  }
  char imagespath[MAX_PATH_LEN];
  memset(imagespath, 0, MAX_PATH_LEN);
  strncpy(imagespath, dirname(dirname(exepath)), MAX_PATH_LEN - 1);
  strncat(imagespath, PATH_SEP "share" PATH_SEP "cartesi-machine" PATH_SEP "images", MAX_PATH_LEN - strnlen(imagespath, MAX_PATH_LEN) - 1);
  setenv("CARTESI_IMAGES_PATH", imagespath, 0);
}

int main(int argc, char **argv) {
  // set CARTESI_IMAGES_PATH if unset
  initimagespath();
  // initialize Lua
  int status = 0;
  lua_State *L = luaL_newstate();
  if (L == NULL) {
    lua_writestringerror("%s\n", "cannot create state: not enough memory");
    return EXIT_FAILURE;
  }
  // stop GC while building state
  lua_gc(L, LUA_GCSTOP);
  // load standard Lua libraries
  luaL_openlibs(L);
  luaopen_cartesi(L);
  setpackageloaded(L, "cartesi");
  luaopen_cartesi_jsonrpc(L);
  setpackageloaded(L, "cartesi.jsonrpc");
  // set "arg"
  createargtable(L, argv, argc);
  // load cartesi dep scripts
  status = dobufferloadpackage(L, cartesi_proof_lua, cartesi_proof_lua_len, "@cartesi/proof.lua", "cartesi.proof");
  if (status != LUA_OK) {
    return report(L, status);
  }
  status = dobufferloadpackage(L, cartesi_util_lua, cartesi_util_lua_len, "@cartesi/util.lua", "cartesi.util");
  if (status != LUA_OK) {
    return report(L, status);
  }
  status = dobufferloadpackage(L, cartesi_gdbstub_lua, cartesi_gdbstub_lua_len, "@cartesi/gdbstub.lua", "cartesi.gdbstub");
  if (status != LUA_OK) {
    return report(L, status);
  }
  // start GC in generational mode
  lua_gc(L, LUA_GCRESTART);
  lua_gc(L, LUA_GCGEN, 0, 0);
  // run "cartesi-machine.lua"
  status = dobuffercall(L, cartesi_machine_lua, cartesi_machine_lua_len, "@cartesi-machine.lua", 0);
  if (status != LUA_OK) {
      return report(L, status);
  }
  // cleanup Lua
  lua_close(L);
  return EXIT_SUCCESS;
}
