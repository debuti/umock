#ifndef _umock_h_
#define _umock_h_

#define FAKENAME(fn, name) fn##name

#define USEFAKE(fn, name) fn##_impl = FAKENAME(fn, name)

#define FAKE(ret, fn, name, param) \
    extern ret(*fn##_impl) param;  \
    ret fn##name param;            \
    ret fn##name param

#define FAKEBODY(name, testsignature, callargs)              \
    name##_fn name##_impl = NULL;                            \
    testsignature;                                           \
    testsignature                                            \
    {                                                        \
        name##_fn impl = (name##_impl ? name##_impl : name); \
        name##_impl = NULL;                                  \
        return impl callargs;                                \
    }

#endif