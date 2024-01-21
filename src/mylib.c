#include "mylib.h"

#include <stdlib.h>

struct mylib_st
{
    int inner;
};

int mylib_init(struct mylib_st **obj)
{
    *obj = malloc(sizeof(struct mylib_st));
    return *obj == NULL;
}

int mylib_term(struct mylib_st *obj)
{
    free(obj);
    return 0;
}