# UMock

Universal Mock (UMock) for CMake based tests. UMock is compiler and test framework agnostic and it can even be used for cross-compiled projects.

## License

UMock © 2024 by Borja Garcia is licensed under [CC BY-SA 4.0](http://creativecommons.org/licenses/by-sa/4.0) 

## Usage

Include it in your project (CMakeLists.txt)
```
include(FetchContent)

# Fetch UMock
FetchContent_Declare(
    umock
    SOURCE_DIR "${CMAKE_SOURCE_DIR}/../../umock/"
)
FetchContent_MakeAvailable(umock)
include(${umock_SOURCE_DIR}/umock/cmake/umock.cmake)
```

Add some mocks to your tester
```
MOCK(void *, malloc, trace, (size_t __size))
{
    printf("Hook on malloc!\n");
    return malloc(__size);
}
```

And use them in the test case
```
static void mylib_test(void **state)
{
    struct mylib_st *opaque;

    MOCKUSE(malloc, trace_and_check);
    assert_int_equal(mylib_init(&opaque), 0); /* mylib_init calls malloc */
}
```

Finally, let UMock detect the needed mocks (CMakeLists.txt)
```
umock_this(SUT $(SYSTEM_UNDER_TEST_CMAKE_TARGET) TESTER $(TESTER_CMAKE_TARGET))
```

See [debuti/umock-examples](https://github.com/debuti/umock-examples) for more usage scenarios.