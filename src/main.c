#include <stdio.h>
#include "mylib.h"

#define ASSERT(c, a) \
    if (!(c))        \
    {                \
        a            \
    }

int main(int argc, char **argv)
{
    struct mylib_st *opaque;
    int result = -1;

    ASSERT(mylib_init(&opaque) == 0, goto finally;);
    ASSERT(mylib_term(opaque) == 0, goto finally;);

    printf("Success!\n");
    result = 0;
finally:
    return result;
}