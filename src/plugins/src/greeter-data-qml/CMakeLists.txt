qt_policy(SET QTP0001 NEW)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB REQUIRED IMPORTED_TARGET glib-2.0)

qt_add_qml_module(greeterdataqml
    URI GreeterData
    VERSION 1.0
    CLASS_NAME GreeterDataPlugin
    PLUGIN_TARGET greeterdataqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/GreeterData"
    SOURCES Catalog.h Catalog.cpp GreeterDataBackend.h GreeterDataBackend.cpp
)
target_link_libraries(greeterdataqml PRIVATE Qt6::Core Qt6::Qml Qt6::Concurrent PkgConfig::GLIB)
include(../PluginInstall.cmake)
plugin_install(greeterdataqml)

if (BUILD_TESTING)
    find_package(Qt6 6.5 COMPONENTS Test REQUIRED)
    qt_add_executable(greeter_data_test test/GreeterDataTests.cpp test/GreeterDataTests.h Catalog.cpp GreeterDataBackend.cpp GreeterDataBackend.h)
    set_target_properties(greeter_data_test PROPERTIES AUTOMOC ON)
    target_link_libraries(greeter_data_test PRIVATE Qt6::Core Qt6::Qml Qt6::Concurrent Qt6::Test PkgConfig::GLIB)
    add_test(NAME greeter_data_test COMMAND greeter_data_test)
endif()
