# Unit tests for the calendar plugin's pure-C++ layer.
# Built only when -DBUILD_TESTING=ON is passed at top-level configure.

find_package(Qt6 6.5 COMPONENTS Test REQUIRED)
qt_standard_project_setup()

qt_add_executable(calendar_test
    CalendarTests.cpp
    ../IcalParser.cpp
    ../EventTypes.cpp
)

target_include_directories(calendar_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(calendar_test PRIVATE
    Qt6::Core
    Qt6::Test
    PkgConfig::LIBICAL
)

add_test(NAME calendar_test COMMAND calendar_test)
