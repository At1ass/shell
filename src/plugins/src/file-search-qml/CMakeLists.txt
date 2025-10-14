# Включаем новую политику ресурса для QML
qt_policy(SET QTP0001 NEW)

# Подключаем rapidfuzz-cpp через FetchContent
include(FetchContent)

FetchContent_Declare(
    rapidfuzz
    GIT_REPOSITORY https://github.com/rapidfuzz/rapidfuzz-cpp.git
    GIT_TAG v3.0.5  # Последняя стабильная версия
)

# Опции для rapidfuzz
set(RAPIDFUZZ_BUILD_TESTING OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(rapidfuzz)

qt_add_qml_module(filesearchqml
    URI FileSearch
    VERSION 1.0
    CLASS_NAME FileSearchPlugin
    PLUGIN_TARGET filesearchqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/FileSearch"
    SOURCES
        FileSearcher.h
        FileSearcher.cpp
)

target_link_libraries(filesearchqml
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        rapidfuzz::rapidfuzz
)

# Переменные установки (как у других плагинов)
set(INSTALL_QMLDIR "usr/lib/qt6/qml" CACHE STRING "QML install dir")

# Функция для установки QML модуля
qt_query_qml_module(filesearchqml
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
install(TARGETS filesearchqml LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(TARGETS "${module_plugin_target}" LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")
