qt_policy(SET QTP0001 NEW)

include(FetchContent)
FetchContent_Declare(
    rapidfuzz
    GIT_REPOSITORY https://github.com/rapidfuzz/rapidfuzz-cpp.git
    GIT_TAG        v3.3.3
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(rapidfuzz)

qt_add_qml_module(fuzzysearchqml
    URI FuzzySearch
    VERSION 1.0
    CLASS_NAME FuzzySearchPlugin
    PLUGIN_TARGET fuzzysearchqml
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/FuzzySearch"
    SOURCES
        FuzzySearch.h FuzzySearch.cpp
)

target_link_libraries(fuzzysearchqml
    PRIVATE
        Qt6::Core Qt6::Qml
        rapidfuzz::rapidfuzz
)

# Установка
set(INSTALL_QMLDIR "usr/lib/qt6/qml" CACHE STRING "QML install dir")

qt_query_qml_module(fuzzysearchqml
    URI module_uri
    VERSION module_version
    PLUGIN_TARGET module_plugin_target
    TARGET_PATH module_target_path
    QMLDIR module_qmldir
    TYPEINFO module_typeinfo
)

message(STATUS "Created QML module ${module_uri}, version ${module_version}")

set(module_dir "${INSTALL_QMLDIR}/${module_target_path}")
install(TARGETS fuzzysearchqml LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(TARGETS "${module_plugin_target}" LIBRARY DESTINATION "${module_dir}" RUNTIME DESTINATION "${module_dir}")
install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")
