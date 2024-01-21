#ifndef _fake_h_
#define _fake_h_

#define MOCKBODY(name, testsignature, callargs) \
name##_fn name##_impl = NULL;\
testsignature;\
testsignature\
{\
    name##_fn impl = (name##_impl?name##_impl:name);\
    name##_impl = NULL;\
    return impl callargs;\
}

#endif