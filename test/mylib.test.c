#include <stdarg.h>
#include <setjmp.h>
#include <stddef.h>
#include <cmocka.h>

#include <stdio.h>
#include <stdlib.h>

#include "mylib.h"
#include "umock.h"

MOCK(void *, malloc, fake1, (size_t __size))
{
    printf("Mocked malloc!");
    check_expected(__size);
    return malloc(__size);
}

MOCK(void, free, fake1, (void *__ptr))
{
    printf("Mocked free!");
    free(__ptr);
}

static void mylib_test(void **state)
{
    struct mylib_st *opaque;

    expect_value(MOCKNAME(malloc, fake1), __size, 4);
    MOCKUSE(malloc, fake1);
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