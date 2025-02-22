# cwebparser/parserapi/CMakeLists.txt

cmake_minimum_required(VERSION 3.20)

set(BASENAME cwebparser.v4)
project(${BASENAME}.parser)

# needed for zero optimization, otherwise some local variables are optimized out
if (CMAKE_CXX_COMPILER_ID MATCHES GNU)
  set(CMAKE_CXX_FLAGS_DEBUG "-O0 -ggdb3" CACHE STRING "" FORCE)
  set(CMAKE_CXX_STANDARD 23 CACHE STRING "" FORCE)
endif()

# standalone parser executable with -DBUILD_MAIN
add_library(cwebparse INTERFACE)
add_dependencies(cwebparse bisonfilesgen)
target_compile_options(cwebparse INTERFACE -Wall -Werror -Wextra -O0 -ggdb3 -std=c++2b)
target_include_directories(cwebparse INTERFACE . ../.. ${CMAKE_CURRENT_BINARY_DIR}/../..)
target_link_libraries(cwebparse INTERFACE cwebbisonparser.v4.flex cwebbisonparser.v4.bison fmt)

# tests

set(TESTNAME ${BASENAME}.gtest)

add_executable(${TESTNAME} ${TESTNAME}.cpp)
#set_target_properties(${TESTNAME} PROPERTIES EXCLUDE_FROM_ALL true)

# for header file generated by bison
#target_include_directories(${TESTNAME} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/../..)

if(CYGWIN)
  target_compile_definitions(${TESTNAME} PRIVATE GTEST_HAS_PTHREAD=1)
endif()
if(CMAKE_CXX_COMPILER_ID MATCHES GNU)
  target_compile_options(${TESTNAME} PRIVATE -Wall -Werror -Wextra -O0 -ggdb3 -std=c++2b)
elseif(CMAKE_CXX_COMPILER_ID MATCHES MSVC)
# ranges library cannot take -Wall -WX
  target_compile_options(${TESTNAME} PRIVATE -Od)
elseif(CMAKE_CXX_COMPILER_ID MATCHES Clang)
  target_compile_definitions(${TESTNAME} PRIVATE _SILENCE_CLANG_CONCEPTS_MESSAGE)
endif()

target_link_libraries(${TESTNAME} gmock_main cwebparse cwebbisonparser.v4.flex cwebbisonparser.v4.bison fmt)

enable_testing()
include(GoogleTest)



