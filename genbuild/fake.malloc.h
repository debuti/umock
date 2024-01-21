#ifndef _fake_malloc_h_
#define _fake_malloc_h_

#include "fake.h"

typedef 
void* (*malloc_fn)(size_t __size);

MOCKBODY(malloc, void *malloc_test (size_t __size), (__size))

#define malloc malloc_test

#endif
#if 0

void *fakemalloc(size_t __size)
{
    printf(".");
    return malloc(__size);
}

#define malloc fakemalloc




extern int gettimeofday_test (struct timeval * __tv, void * __tz);
#define gettimeofday gettimeofday_test
#endif