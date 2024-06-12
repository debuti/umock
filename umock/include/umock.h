#ifndef _umock_h_
#define _umock_h_

#define USE_ONCE (1)

#define MOCKNAME(fn, name) fn##name

/** Use a mock variant only once. Other calls will be directed
 * to th mocked fn directly
 *
 * @param fn The name of the fn to be mocked
 * @param name The variant of the mock
 *
 */
#define MOCKUSEONCE(fn, name)           \
    do {                                \
        fn##_impl = MOCKNAME(fn, name); \
        fn##_flags |= USE_ONCE;         \
    } while (0)

/** Use a mock variant every time the mocked fn gets called
 *
 * @param fn The name of the fn to be mocked
 * @param name The variant of the mock
 *
 */
#define MOCKUSEALWAYS(fn, name)         \
    do {                                \
        fn##_impl = MOCKNAME(fn, name); \
        fn##_flags &= ~USE_ONCE;        \
    } while (0)

/** Create a new mock variant
 *
 * @param ret The return type for the fn to be mocked
 * @param fn The name of the fn to be mocked
 * @param name The variant of the mock. This allows to define
 * 	several mocks for the same function
 * @param param The list of parameters of the fn to be mocked
 *
 */
#define MOCK(ret, fn, name, param)   \
    extern unsigned char fn##_flags; \
    extern ret(*fn##_impl) param;    \
    ret MOCKNAME(fn, name) param;    \
    ret MOCKNAME(fn, name) param

#define MOCKENTRY(name, testsignature, callargs)             \
    unsigned char name##_flags = 0;                          \
    name##_fn name##_impl = ((void *)0);                     \
    testsignature;                                           \
    testsignature                                            \
    {                                                        \
        name##_fn impl = (name##_impl ? name##_impl : name); \
        if (name##_flags & USE_ONCE)                         \
            name##_impl = ((void *)0);                       \
        return impl callargs;                                \
    }

#endif
