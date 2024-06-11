#ifndef _umock_h_
#define _umock_h_

#define MOCKNAME(fn, name) fn##name

#define MOCKUSE(fn, name) fn##_impl = MOCKNAME(fn, name)

/** Create a new mock
 *
 * @param ret The return type for the fn to be mocked
 * @param fn The name of the fn to be mocked
 * @param name The variant of the mock. This allows to define
 * 	several mocks for the same function
 * @param param The list of parameters of the fn to be mocked
 *
 */
#define MOCK(ret, fn, name, param) \
    extern ret(*fn##_impl) param;  \
    ret MOCKNAME(fn, name) param;  \
    ret MOCKNAME(fn, name) param

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
