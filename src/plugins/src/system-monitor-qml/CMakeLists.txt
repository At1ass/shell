# Включаем новую политику ресурса для QML
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
)

find_path(SENSORS_INCLUDE_DIR
    NAMES sensors/sensors.h
    PATHS /usr/include /usr/local/include
)

# Ищем библиотеку
find_library(SENSORS_LIB
    NAMES sensors
    PATHS /usr/lib /usr/local/lib
)

if (NOT SENSORS_INCLUDE_DIR)
    message(WARNING "Could not find sensors/sensors.h")
endif()

if (NOT SENSORS_LIB)
    message(WARNING "Could not find libsensors.so")
else()
    target_compile_definitions(systemmonitorqml PRIVATE HAVE_LIBSENSORS)
endif()

target_include_directories(systemmonitorqml
    PRIVATE
        ${SENSORS_INCLUDE_DIR}
)

target_link_libraries(systemmonitorqml
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        # ${LIBSENSORS_LIB}
        ${SENSORS_LIB}
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
