cmake_minimum_required(VERSION 3.21)
project(quickshell-plugins LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 COMPONENTS Core Gui Qml Concurrent REQUIRED)

add_subdirectory(external/mcu-cpp)  # делает target mcu-cpp, см. их CMake
add_subdirectory(src/mcu-qml)
add_subdirectory(src/qalculate-qml)
add_subdirectory(src/system-monitor-qml)
add_subdirectory(src/fuzzy-search-qml)
add_subdirectory(src/calendar-qml)
