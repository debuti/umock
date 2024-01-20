#include <stdarg.h>
#include <setjmp.h>
#include <stddef.h>
#include <cmocka.h>

#include "mylib.h"

static void mylib_test(void **state)
{
    assert_int_equal(stuff(), 0);
}

int main()
{
    const struct CMUnitTest tests[] =
    {
        cmocka_unit_test(mylib_test),
    };

    return cmocka_run_group_tests(tests, NULL, NULL);
}