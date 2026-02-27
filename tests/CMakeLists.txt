cmake_minimum_required(VERSION 3.10)
project(tests)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(GTest REQUIRED)
include_directories(${GTEST_INCLUDE_DIRS})
include_directories(${CMAKE_SOURCE_DIR}/../include)
include_directories(${CMAKE_SOURCE_DIR}/../..)
file(GLOB TEST_SOURCES
    "${CMAKE_SOURCE_DIR}/indicators/test_*.cc"
    "${CMAKE_SOURCE_DIR}/streamers/test_*.cc"
    "${CMAKE_SOURCE_DIR}/strategies/test_*.cc"
)
add_executable(tests ${TEST_SOURCES} ${CMAKE_SOURCE_DIR}/indicators/main.cc)
target_link_libraries(tests ${GTEST_LIBRARIES} pthread)
target_include_directories(tests PRIVATE ${CMAKE_SOURCE_DIR}/../include)
target_include_directories(tests PRIVATE ${CMAKE_SOURCE_DIR}/../../include)
enable_testing()
add_test(NAME tests COMMAND tests)
