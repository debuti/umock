#include <stdarg.h>
#include <setjmp.h>
#include <stddef.h>
#include <cmocka.h>

#include <stdio.h>
#include <stdlib.h>

#include "mylib.h"

void *fakemalloc(size_t __size)
{
    printf("Faked!");
    return malloc(__size);
}

extern void* (*malloc_impl)(size_t __size);

static void mylib_test(void **state)
{
    struct mylib_st * opaque;

    malloc_impl = fakemalloc;
    assert_int_equal(mylib_init(&opaque), 0);
    assert_int_equal(mylib_term(opaque), 0);
}

int main()
{
    const struct CMUnitTest tests[] =
    {
        cmocka_unit_test(mylib_test),
    };

    return cmocka_run_group_tests(tests, NULL, NULL);
}