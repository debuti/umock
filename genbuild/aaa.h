
#ifndef TESTSUITE_mockedfns_h
#define TESTSUITE_mockedfns_h

#ifdef __cplusplus
    extern "C" {
#endif

#include "test/test_setting.h"

#include "osapi/osapi_system.h"

#if defined(RTI_UNIX)
/* Claim compliance with IEEE Std 1003.1, 2004 Edition */
#ifdef _POSIX_C_SOURCE
#undef _POSIX_C_SOURCE
#endif
#define _POSIX_C_SOURCE 200112L

#ifdef _XOPEN_SOURCE
#undef _XOPEN_SOURCE
#endif
#define _XOPEN_SOURCE 600

#include <unistd.h>
#include <string.h>
#include <sys/time.h>
#include <pthread.h>
#include <sys/socket.h>

FUNCTION_SHOULD_TYPEDEF(
int
(*pthread_mutex_lock_fn)(pthread_mutex_t *__mutex)
)
extern pthread_mutex_lock_fn pthread_mutex_lock_impl;

FUNCTION_SHOULD_TYPEDEF(
int
(*pthread_mutex_unlock_fn)(pthread_mutex_t *__mutex)
)
extern pthread_mutex_unlock_fn pthread_mutex_unlock_impl;

FUNCTION_SHOULD_TYPEDEF(
int
(*gethostname_fn)(char *__name, size_t __len)
)
extern gethostname_fn gethostname_impl;

FUNCTION_SHOULD_TYPEDEF(
int
(*gettimeofday_fn)(struct timeval * __tv, void * __tz)
)
extern gettimeofday_fn gettimeofday_impl;

FUNCTION_SHOULD_TYPEDEF(
int
(*socket_fn)(int __domain, int __type, int __protocol)
)
extern socket_fn socket_impl;

#endif

#ifdef __cplusplus
    }
#endif

#endif



#include "TESTSUITE_PSL_mockedfns.h"

#define MOCKBODY(name, testsignature, callargs) \
name##_fn name##_impl = NULL;\
testsignature;\
testsignature\
{\
    name##_fn impl = (name##_impl?name##_impl:name);\
    name##_impl = NULL;\
    return impl callargs;\
}

MOCKBODY(pthread_mutex_lock, int pthread_mutex_lock_test (pthread_mutex_t *__mutex), (__mutex))

MOCKBODY(pthread_mutex_unlock, int pthread_mutex_unlock_test (pthread_mutex_t *__mutex), (__mutex))

MOCKBODY(gethostname, int gethostname_test(char *__name, size_t __len), (__name, __len))

MOCKBODY(gettimeofday, int gettimeofday_test (struct timeval * __tv, void * __tz), (__tv, __tz))

MOCKBODY(socket, int socket_test (int __domain, int __type, int __protocol), (__domain, __type, __protocol))