#ifndef _umock_h_
#define _umock_h_

#define MOCKNAME(fn, name) fn##_##name

/** Use a mock variant only once. Other calls will be directed
 * to th mocked fn directly
 *
 * @param fn The name of the fn to be mocked
 * @param name The variant of the mock
 *
 */
#define MOCKUSEONCE(fn, name)                  \
    do                                         \
    {                                          \
        fn##_idx = 0;                          \
        fn##_size = 2;                         \
        fn##_impl[0] = MOCKNAME(fn, name);     \
        fn##_impl[1] = ((fn##_fn)((void *)0)); \
    } while (0)

/** Setup the environment to use
 *
 * This code will assert at runtime if the requested
 * invocations are within configured bounds.
 *
 * @param fn The name of the fn to be mocked
 * @param n The number of expected invocations
 *
 */
#define MOCKSETMANY(fn, n)                             \
    do                                                 \
    {                                                  \
        unsigned int __idx;                            \
        if (n >= UMOCK_MOCK_MAGAZINE_MAX)              \
            for (;;)                                   \
                ;                                      \
        fn##_idx = 0;                                  \
        fn##_size = n + 1;                             \
        for (__idx = 0; __idx < fn##_size; __idx += 1) \
            fn##_impl[__idx] = ((fn##_fn)((void *)0)); \
    } while (0)

/** Setup the environment to use
 *
 * @param fn The name of the fn to be mocked
 * @param n The number of expected invocations
 *
 */
#define MOCKSETIDX(fn, name, i)            \
    do                                     \
    {                                      \
        fn##_impl[i] = MOCKNAME(fn, name); \
    } while (0)

/** Use a mock variant every time the mocked fn gets called
 *
 * @param fn The name of the fn to be mocked
 * @param name The variant of the mock
 *
 */
#define MOCKUSEALWAYS(fn, name)            \
    do                                     \
    {                                      \
        fn##_idx = 0;                      \
        fn##_size = 1;                     \
        fn##_impl[0] = MOCKNAME(fn, name); \
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
#define MOCK(ret, fn, name, param) \
    typedef ret(*fn##_fn) param;   \
    extern unsigned int fn##_idx;  \
    extern unsigned int fn##_size; \
    extern fn##_fn fn##_impl[];    \
    ret MOCKNAME(fn, name) param;  \
    ret MOCKNAME(fn, name) param

#define MOCKENTRY(name, testsignature, callargs)                                     \
    name##_fn name##_impl[UMOCK_MOCK_MAGAZINE_MAX] = {((void *)0)};                  \
    unsigned int name##_idx = 0;                                                     \
    unsigned int name##_size = 0;                                                    \
    testsignature;                                                                   \
    testsignature                                                                    \
    {                                                                                \
        name##_fn impl = (name##_impl[name##_idx] ? name##_impl[name##_idx] : name); \
        if ((name##_idx + 1) < name##_size)                                          \
            name##_idx++;                                                            \
        return impl callargs;                                                        \
    }

#endif
