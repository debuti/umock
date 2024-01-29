#include <stdarg.h>
#include <setjmp.h>
#include <stddef.h>
#include <cmocka.h>

#include <stdio.h>
#include <stdlib.h>

#include "mylib.h"
#include "umock.h"

FAKE(void *, malloc, fake1, (size_t __size))
{
    printf("Faked!");
    check_expected(__size);
    return malloc(__size);
}

static void mylib_test(void **state)
{
    struct mylib_st *opaque;

    expect_value(FAKENAME(malloc, fake1), __size, 4);
    USEFAKE(malloc, fake1);
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