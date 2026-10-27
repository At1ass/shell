qt_policy(SET QTP0001 NEW)
qt_add_qml_module(connectivityqml
    URI Connectivity VERSION 1.0 CLASS_NAME ConnectivityPlugin PLUGIN_TARGET connectivityqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Connectivity"
    SOURCES VpnProfiles.h VpnProfiles.cpp
        NetworkInterfaceInfo.h NetworkInterfaceInfo.cpp
        BluetoothPairingAgent.h BluetoothPairingAgent.cpp
        NetworkSecretAgent.h NetworkSecretAgent.cpp NetworkSettings.h
        NetworkCredentials.h NetworkCredentials.cpp CredentialStore.h CredentialStore.cpp VpnUiHelper.h VpnUiHelper.cpp
)
find_package(Qt6 6.5 COMPONENTS Network REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBSECRET REQUIRED IMPORTED_TARGET libsecret-1)
target_link_libraries(connectivityqml PRIVATE Qt6::Core Qt6::Qml Qt6::DBus Qt6::Network Qt6::Concurrent PkgConfig::LIBSECRET)
include(../PluginInstall.cmake)
plugin_install(connectivityqml)
if (BUILD_TESTING)
    find_package(Qt6 6.5 COMPONENTS Test REQUIRED)
    qt_add_executable(bluetooth_agent_test test/BluetoothAgentTests.cpp test/BluetoothAgentTests.h BluetoothPairingAgent.cpp BluetoothPairingAgent.h)
    set_target_properties(bluetooth_agent_test PROPERTIES AUTOMOC ON)
    target_link_libraries(bluetooth_agent_test PRIVATE Qt6::Core Qt6::Qml Qt6::DBus Qt6::Test)
    qt_add_executable(network_agent_test test/NetworkAgentTests.cpp test/NetworkAgentTests.h
        NetworkSecretAgent.cpp NetworkSecretAgent.h NetworkSettings.h NetworkCredentials.cpp
        CredentialStore.cpp VpnUiHelper.cpp)
    set_target_properties(network_agent_test PROPERTIES AUTOMOC ON)
    target_link_libraries(network_agent_test PRIVATE Qt6::Core Qt6::Qml Qt6::DBus Qt6::Concurrent Qt6::Test PkgConfig::LIBSECRET)
    qt_add_executable(network_info_test test/NetworkInfoTests.cpp NetworkInterfaceInfo.cpp NetworkInterfaceInfo.h)
    set_target_properties(network_info_test PROPERTIES AUTOMOC ON)
    target_link_libraries(network_info_test PRIVATE Qt6::Core Qt6::Qml Qt6::DBus Qt6::Network Qt6::Test)
    qt_add_executable(vpn_profiles_test test/VpnProfilesTests.cpp VpnProfiles.cpp VpnProfiles.h NetworkSettings.h)
    set_target_properties(vpn_profiles_test PROPERTIES AUTOMOC ON)
    target_link_libraries(vpn_profiles_test PRIVATE Qt6::Core Qt6::Qml Qt6::DBus Qt6::Test)
    add_test(NAME vpn_profiles_test COMMAND dbus-run-session -- $<TARGET_FILE:vpn_profiles_test>)
    add_test(NAME network_info_test COMMAND dbus-run-session -- $<TARGET_FILE:network_info_test>)
    add_test(NAME network_agent_test COMMAND dbus-run-session -- $<TARGET_FILE:network_agent_test>)
    add_test(NAME bluetooth_agent_test COMMAND dbus-run-session -- $<TARGET_FILE:bluetooth_agent_test>)
endif()
