cmake_minimum_required(VERSION 3.10)
project(native_logic CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(native_logic SHARED native_logic.cpp)

# En Release: optimización agresiva y solo se exportan los símbolos marcados
# con FFI_EXPORT. (CMake ya define NDEBUG en Release, lo que desactiva LOG()).
target_compile_options(native_logic PRIVATE
    $<$<CONFIG:Release>:-O3 -fvisibility=hidden>)
