qt_policy(SET QTP0001 NEW)
qt_add_qml_module(connectivityqml
    URI Connectivity VERSION 1.0 CLASS_NAME ConnectivityPlugin PLUGIN_TARGET connectivityqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Connectivity"
    SOURCES BluetoothPairingAgent.h BluetoothPairingAgent.cpp
)
target_link_libraries(connectivityqml PRIVATE Qt6::Core Qt6::Qml Qt6::DBus)
include(../PluginInstall.cmake)
plugin_install(connectivityqml)
if (BUILD_TESTING)
    find_package(Qt6 6.5 COMPONENTS Test REQUIRED)
    qt_add_executable(bluetooth_agent_test test/BluetoothAgentTests.cpp test/BluetoothAgentTests.h BluetoothPairingAgent.cpp BluetoothPairingAgent.h)
    set_target_properties(bluetooth_agent_test PROPERTIES AUTOMOC ON)
    target_link_libraries(bluetooth_agent_test PRIVATE Qt6::Core Qt6::Qml Qt6::DBus Qt6::Test)
    add_test(NAME bluetooth_agent_test COMMAND dbus-run-session -- $<TARGET_FILE:bluetooth_agent_test>)
endif()
