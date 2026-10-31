# QML resource policy
qt_policy(SET QTP0001 NEW)

qt_add_qml_module(systemmonitorqml
    URI SystemMonitor
    VERSION 1.0
    CLASS_NAME SystemMonitorPlugin
    PLUGIN_TARGET systemmonitorqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/SystemMonitor"
    SOURCES
        SystemMonitor.h
        SystemMonitor.cpp
        StorageCollector.h
        StorageCollector.cpp
        SessionIdleInhibitor.h
        SessionIdleInhibitor.cpp
)

# libsensors is genuinely optional: referencing the *-NOTFOUND variables
# unconditionally used to turn "not installed" into a hard configure error.
find_path(SENSORS_INCLUDE_DIR
    NAMES sensors/sensors.h
    PATHS /usr/include /usr/local/include
)
find_library(SENSORS_LIB
    NAMES sensors
    PATHS /usr/lib /usr/local/lib
)

if (SENSORS_INCLUDE_DIR AND SENSORS_LIB)
    target_compile_definitions(systemmonitorqml PRIVATE HAVE_LIBSENSORS)
    target_include_directories(systemmonitorqml PRIVATE ${SENSORS_INCLUDE_DIR})
    target_link_libraries(systemmonitorqml PRIVATE ${SENSORS_LIB})
else()
    message(WARNING "libsensors not found — building SystemMonitor without hwmon temperature support")
endif()

target_link_libraries(systemmonitorqml
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::DBus
)

include(../PluginInstall.cmake)
plugin_install(systemmonitorqml)

if (BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    add_executable(storage_test test/StorageTests.cpp StorageCollector.cpp)
    set_target_properties(storage_test PROPERTIES AUTOMOC ON)
    target_include_directories(storage_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    target_link_libraries(storage_test PRIVATE Qt6::Core Qt6::Test)
    add_test(NAME storage_test COMMAND storage_test)
    qt_add_executable(session_idle_test test/SessionIdleInhibitorTests.cpp SessionIdleInhibitor.cpp SessionIdleInhibitor.h)
    set_target_properties(session_idle_test PROPERTIES AUTOMOC ON)
    target_link_libraries(session_idle_test PRIVATE Qt6::Core Qt6::Qml Qt6::DBus Qt6::Test)
    add_test(NAME session_idle_test COMMAND session_idle_test)
endif()
