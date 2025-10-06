cmake_minimum_required(VERSION 3.21)
project(mcu-qml LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 COMPONENTS Core Gui Qml REQUIRED)

add_subdirectory(external/mcu-cpp)  # делает target mcu-cpp, см. их CMake
add_subdirectory(src/mcu-qml)
