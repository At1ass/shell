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

target_link_libraries(mcuqml
  PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml
    Qt6::Concurrent
    mcu-cpp
)

include(../PluginInstall.cmake)
plugin_install(mcuqml)

if (BUILD_TESTING)
    add_subdirectory(test)
endif()
