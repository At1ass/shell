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

include(../PluginInstall.cmake)
plugin_install(fuzzysearchqml)
