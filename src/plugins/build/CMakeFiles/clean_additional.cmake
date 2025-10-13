# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Release")
  file(REMOVE_RECURSE
  "src/mcu-qml/CMakeFiles/mcuqml_autogen.dir/AutogenUsed.txt"
  "src/mcu-qml/CMakeFiles/mcuqml_autogen.dir/ParseCache.txt"
  "src/mcu-qml/mcuqml_autogen"
  "src/qalculate-qml/CMakeFiles/qalculateqml_autogen.dir/AutogenUsed.txt"
  "src/qalculate-qml/CMakeFiles/qalculateqml_autogen.dir/ParseCache.txt"
  "src/qalculate-qml/qalculateqml_autogen"
  )
endif()
