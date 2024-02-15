#ifndef _umock_h_
#define _umock_h_

#define MOCKNAME(fn, name) fn##name

#define MOCKUSE(fn, name) fn##_impl = MOCKNAME(fn, name)

#define MOCK(ret, fn, name, param) \
    extern ret(*fn##_impl) param;  \
    ret fn##name param;            \
    ret fn##name param

#define MOCKBODY(name, testsignature, callargs)              \
    name##_fn name##_impl = NULL;                            \
    testsignature;                                           \
    testsignature                                            \
    {                                                        \
        name##_fn impl = (name##_impl ? name##_impl : name); \
        name##_impl = NULL;                                  \
        return impl callargs;                                \
    }

#endif