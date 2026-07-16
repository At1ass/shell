# Включаем новую политику ресурса для QML
qt_policy(SET QTP0001 NEW)

# Найти libqalculate через pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(QALCULATE REQUIRED IMPORTED_TARGET libqalculate)

qt_add_qml_module(qalculateqml
    URI Qalculate
    VERSION 1.0
    CLASS_NAME QalculatePlugin
    PLUGIN_TARGET qalculateqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Qalculate"
    SOURCES
        QalculateWrapper.h
        QalculateWrapper.cpp
)

target_link_libraries(qalculateqml
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Concurrent
        PkgConfig::QALCULATE
)

include(../PluginInstall.cmake)
plugin_install(qalculateqml)
