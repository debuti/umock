#ifndef _umock_h_
#define _umock_h_

#define MOCKNAME(fn, name) fn##name

/** Use a mock variant only once. Other calls will be directed
 * to th mocked fn directly
 *
 * @param fn The name of the fn to be mocked
 * @param name The variant of the mock
 *
 */
#define MOCKUSEONCE(fn, name)                            \
    do {                                                 \
        fn##_idx = 0;                                    \
        fn##_size = 2;                                   \
        fn##_impl = (fn##_fn*) calloc(2, sizeof(void*)); \
        fn##_impl[0] = MOCKNAME(fn, name);               \
    } while (0)

/** Setup the environment to use
 *
 * @param fn The name of the fn to be mocked
 * @param n The number of expected invocations
 *
 */
#define MOCKSETMANY(fn, n)                               \
    do {                                                 \
        fn##_idx = 0;                                    \
        fn##_size = n;                                   \
        fn##_impl = (fn##_fn*) calloc(n, sizeof(void*)); \
    } while (0)

/** Setup the environment to use
 *
 * @param fn The name of the fn to be mocked
 * @param n The number of expected invocations
 *
 */
#define MOCKSETIDX(fn, name, i)            \
    do {                                   \
        fn##_impl[i] = MOCKNAME(fn, name); \
    } while (0)

/** Use a mock variant every time the mocked fn gets called
 *
 * @param fn The name of the fn to be mocked
 * @param name The variant of the mock
 *
 */
#define MOCKUSEALWAYS(fn, name)                          \
    do {                                                 \
        fn##_idx = 0;                                    \
        fn##_size = 1;                                   \
        fn##_impl = (fn##_fn*) calloc(1, sizeof(void*)); \
        fn##_impl[0] = MOCKNAME(fn, name);               \
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
    typedef ret(*fn##_fn)param;    \
    extern unsigned int fn##_idx;  \
    extern unsigned int fn##_size; \
    extern fn##_fn * fn##_impl;    \
    ret MOCKNAME(fn, name) param;  \
    ret MOCKNAME(fn, name) param


#define MOCKENTRY(name, testsignature, callargs)                                                            \
    name##_fn * name##_impl = ((void *)0);                                                                  \
    unsigned int name##_idx = 0;                                                                            \
    unsigned int name##_size = 0;                                                                           \
    testsignature;                                                                                          \
    testsignature                                                                                           \
    {                                                                                                       \
        name##_fn impl = (name##_impl ? (name##_impl[name##_idx] ? name##_impl[name##_idx] : name) : name); \
        if ((name##_idx + 1) < name##_size)                                                                 \
            name##_idx++;                                                                                   \
        return impl callargs;                                                                               \
    }

#endif
