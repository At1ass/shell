cmake_minimum_required(VERSION 3.21)
project(quickshell-plugins LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_compile_options(-Wall -Wextra)

find_package(Qt6 6.5 COMPONENTS Core Gui Qml Concurrent DBus REQUIRED)

if (BUILD_TESTING)
    enable_testing()
endif()

add_subdirectory(external/mcu-cpp)  # provides target mcu-cpp
add_subdirectory(src/mcu-qml)
add_subdirectory(src/qalculate-qml)
add_subdirectory(src/system-monitor-qml)
add_subdirectory(src/fuzzy-search-qml)
add_subdirectory(src/calendar-qml)
add_subdirectory(src/greeter-data-qml)

if (BUILD_TESTING)
    add_subdirectory(src/common/test)
endif()
