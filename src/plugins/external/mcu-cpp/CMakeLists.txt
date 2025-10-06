cmake_minimum_required(VERSION 3.16)

set(CMAKE_CXX_STANDARD 17)
# Корень репозитория MCU (папка, где есть подкаталог cpp/)
set(MCU_ROOT ${CMAKE_CURRENT_LIST_DIR}/../material-color-utilities)
set(MCU_CPP  ${MCU_ROOT}/cpp)

# Берём все .cc из cpp/, но без тестов
file(GLOB_RECURSE MCU_SOURCES CONFIGURE_DEPENDS
    "${MCU_CPP}/*.cc"
)
list(FILTER MCU_SOURCES EXCLUDE REGEX "_test\\.cc$")

add_library(mcu-cpp STATIC ${MCU_SOURCES})

# GCC/Clang: принудительно подключить <optional> перед всеми их заголовками
if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(mcu-cpp PRIVATE -include optional)
endif()
# В include добавляем ИМЕННО корень, чтобы пути "cpp/xxx.h" находились
target_include_directories(mcu-cpp PUBLIC ${MCU_ROOT})

# На всякий случай PIC (полезно для плагина)
set_target_properties(mcu-cpp PROPERTIES POSITION_INDEPENDENT_CODE ON)

# (опционально) приглушить варнинги на внешнем коде
if (MSVC)
  target_compile_options(mcu-cpp PRIVATE /W0)
else()
  target_compile_options(mcu-cpp PRIVATE -w)
endif()

