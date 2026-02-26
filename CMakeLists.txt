cmake_minimum_required(VERSION 4.0)
project(tzutrader)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(SRC_DIR "${CMAKE_SOURCE_DIR}/src")
set(INCLUDE_DIR "${CMAKE_SOURCE_DIR}/include")
file(GLOB LIB_SOURCES 
    "${SRC_DIR}/indicators/*.cc"
    "${SRC_DIR}/strategies/*.cc")
add_library(tzutrader STATIC ${LIB_SOURCES})
include_directories(${INCLUDE_DIR})
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(tzutrader PRIVATE -g -O0 -Wall -Wextra
        -pedantic)
else()
    target_compile_options(tzutrader PRIVATE -O3 -march=native -DNDEBUG -Wall -Wextra)
endif()
