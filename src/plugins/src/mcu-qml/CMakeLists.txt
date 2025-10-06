# Включаем новую политику ресурса для QML (чтобы убрать предупреждение)
qt_policy(SET QTP0001 NEW)

qt_add_qml_module(mcuqml
    URI Mcu
    VERSION 1.0
    CLASS_NAME McuPlugin
    PLUGIN_TARGET mcuqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Mcu"  # путь должен заканчиваться на 'Mcu'
    SOURCES
      McuTheme.h McuTheme.cpp
)

# Найти Abseil - зависимость material-color-utilities
find_package(absl REQUIRED)
# Используем современный CMake подход для Abseil

target_link_libraries(mcuqml
  PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml
    mcu-cpp
    absl::strings
    absl::hash
    absl::base
    absl::container_common
    absl::container_memory
    absl::hash_container_defaults
    absl::raw_hash_set
)

# Переменные установки (как у Caelestia)
set(INSTALL_QMLDIR "usr/lib/qt6/qml" CACHE STRING "QML install dir")

# Функция для установки QML модуля (по образцу Caelestia)
qt_query_qml_module(mcuqml
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
install(TARGETS mcuqml LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(TARGETS "${module_plugin_target}" LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")

