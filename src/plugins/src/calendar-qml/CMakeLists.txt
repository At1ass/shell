# Calendar plugin — libical-backed VEVENT reader/writer with vdir support
qt_policy(SET QTP0001 NEW)

find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBICAL REQUIRED IMPORTED_TARGET libical)

qt_add_qml_module(calendarqml
    URI Calendar
    VERSION 1.0
    CLASS_NAME CalendarPlugin
    PLUGIN_TARGET calendarqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Calendar"
    SOURCES
        IcalRaii.h
        EventTypes.h
        EventTypes.cpp
        Atomic.h
        Atomic.cpp
        IcalParser.h
        IcalParser.cpp
        CalendarStore.h
        CalendarStore.cpp
        ReminderEngine.h
        ReminderEngine.cpp
        CalendarBackend.h
        CalendarBackend.cpp
)

target_link_libraries(calendarqml
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        PkgConfig::LIBICAL
)

include(../PluginInstall.cmake)
plugin_install(calendarqml)

# Optional unit tests — enabled with -DBUILD_TESTING=ON
if (BUILD_TESTING)
    enable_testing()
    add_subdirectory(test)
endif()
