cmake_minimum_required(VERSION 3.5)

project(cfake_demo
    VERSION 0.1.0
    LANGUAGES C)

# Build mylib
include(${CMAKE_CURRENT_SOURCE_DIR}/src/CMakeLists.txt)

add_library(mylib STATIC
    ${src_SRC_C}
)

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
target_include_directories(mylib_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(mylib_test PRIVATE cmocka mylib)

enable_testing()

add_test(NAME mylib_test COMMAND mylib_test)
