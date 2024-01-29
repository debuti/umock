cmake_minimum_required(VERSION 3.5)

function(umock_this)
    set(flags)
    set(singleargs SUT TESTER)
    set(multiargs)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if((NOT ARG_SUT) OR (NOT (TARGET ${ARG_SUT})))
        message(FATAL_ERROR "You must provide a valid system under test target")
    endif()
    if((NOT ARG_TESTER) OR (NOT (TARGET ${ARG_TESTER})))
        message(FATAL_ERROR "You must provide a valid tester target")
    endif()

    SET(UMOCK_TMP ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${ARG_TESTER}.dir/gen)
    get_target_property(${ARG_SUT}_src      ${ARG_SUT} SOURCES)
    get_target_property(${ARG_SUT}_pub_hdr  ${ARG_SUT} PUBLIC_HEADER)
    get_target_property(${ARG_SUT}_priv_hdr ${ARG_SUT} PRIVATE_HEADER)

    # TODO:
    # This needs to be included automatically by the generator. The default include path in gcc is: echo | gcc -xc -E -v -
    target_include_directories(mylib BEFORE PRIVATE ${UMOCK_TMP}) #${CMAKE_CURRENT_SOURCE_DIR}/genbuild)
    target_include_directories(mylib PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/cfake/include)

    file(COPY /usr/include/stdlib.h
        DESTINATION ${UMOCK_TMP}
    )
    file(APPEND ${UMOCK_TMP}/stdlib.h
        "\n\
/* UMock hook */
#include \"fake.malloc.h\" \
")

    file(APPEND ${UMOCK_TMP}/fake.malloc.h 
         "\n\
#ifndef _umock_malloc_h_ \n\
#define _umock_malloc_h_ \n\
\n\
#include \"umock.h\" \n\
\n\
typedef void *(*malloc_fn)(size_t __size); \n\
\n\
FAKEBODY(malloc, void *malloc_test(size_t __size), (__size)) \n\
\n\
#define malloc malloc_test \n\
\n\
#endif \n\
")

    # file(MAKE_DIRECTORY ${UMOCK_TMP})  # Not needed
   
    # file(APPEND ${UMOCK_TMP}/deleteme "${mylib_src}")
    # file(APPEND ${UMOCK_TMP}/deleteme "${mylib_pub_hdr}")
    # file(APPEND ${UMOCK_TMP}/deleteme "${mylib_priv_hdr}")


endfunction()

project(cfake_demo
    VERSION 0.1.0
    LANGUAGES C)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

# Build mylib
add_library(mylib STATIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/mylib.c
)
target_compile_features(mylib PRIVATE c_std_99)

# Build mylib_app
add_executable(mylib_app
    ${CMAKE_CURRENT_SOURCE_DIR}/src/main.c
)
target_compile_features(mylib_app PRIVATE c_std_99)
target_link_libraries(mylib_app PRIVATE mylib)

if (TESTING)
    # Fetch UMock/CFake
    # TODO

    # Fetch CMocka
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "CMocka: Build as a shared library" FORCE)
    set(WITH_EXAMPLES OFF CACHE BOOL "CMocka: Build examples" FORCE)
    set(UNIT_TESTING OFF CACHE BOOL "CMocka: Build with unit testing" FORCE)
    include(FetchContent)
    FetchContent_Declare(
        cmocka
        GIT_REPOSITORY https://git.cryptomilk.org/projects/cmocka.git
        GIT_TAG        cmocka-1.1.6
        GIT_SHALLOW    1
    )
    FetchContent_MakeAvailable(cmocka)

    # Build mylib tester
    add_executable(mylib_test test/mylib.test.c)
    target_compile_features(mylib_test PRIVATE c_std_99)
    target_include_directories(mylib_test PRIVATE 
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/cfake/include)
    target_link_libraries(mylib_test PRIVATE cmocka mylib)
    
    umock_this(SUT mylib TESTER mylib_test)
    # enable_testing()
    # add_test(NAME mylib_test COMMAND mylib_test)
endif()
