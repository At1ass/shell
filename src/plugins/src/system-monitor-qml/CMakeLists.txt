# Включаем новую политику ресурса для QML
qt_policy(SET QTP0001 NEW)

# # Найти libqalculate через pkg-config
# find_package(PkgConfig REQUIRED)
# pkg_check_modules(QALCULATE REQUIRED IMPORTED_TARGET libqalculate)
#
qt_add_qml_module(systemmonitorqml
    URI SystemMonitor
    VERSION 1.0
    CLASS_NAME SystemMonitorPlugin
    PLUGIN_TARGET systemmonitorqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/SystemMonitor"
    SOURCES
        SystemMonitor.h
        SystemMonitor.cpp
)

target_link_libraries(systemmonitorqml
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
)

# Переменные установки (как у mcu-qml)
set(INSTALL_QMLDIR "usr/lib/qt6/qml" CACHE STRING "QML install dir")

# Функция для установки QML модуля
qt_query_qml_module(systemmonitorqml
    URI module_uri
    VERSION module_version
    PLUGIN_TARGET module_plugin_target
    TARGET_PATH module_target_path
    QMLDIR module_qmldir
    TYPEINFO module_typeinfo
)

message(STATUS "Created QML module ${module_uri}, version ${module_version}")

# Установка плагина в правильную папку
set(module_dir "${INSTALL_QMLDIR}/${module_target_path}")
install(TARGETS systemmonitorqml LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(TARGETS "${module_plugin_target}" LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")
