# A toolchain for Unreal Engine 5 Linux

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(UNIX 1)

set(CLANG_TOOLCHAIN_ROOT "$ENV{LINUX_MULTIARCH_ROOT}/$ENV{LINUX_ARCH_NAME}")
set(LINUX_ARCH_NAME "$ENV{LINUX_ARCH_NAME}")
set(CLANG_TOOLCHAIN_BIN "${CLANG_TOOLCHAIN_ROOT}/bin")
set(UE_THIRD_PARTY_PATH "$ENV{UE_THIRD_PARTY_PATH}")

set(CMAKE_C_COMPILER_WORKS 1)
set(CMAKE_CXX_COMPILER_WORKS 1)

set(CMAKE_STATIC_LIBRARY_SUFFIX ".a")
set(CMAKE_STATIC_LIBRARY_SUFFIX_CXX ".a")

set(CMAKE_FIND_ROOT_PATH ${CLANG_TOOLCHAIN_ROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(CMAKE_C_COMPILER	${CLANG_TOOLCHAIN_BIN}/clang 							CACHE PATH "compiler" FORCE)
set(CMAKE_CXX_COMPILER	${CLANG_TOOLCHAIN_BIN}/clang++							CACHE STRING "" FORCE)
set(CMAKE_LINKER 		${CLANG_TOOLCHAIN_BIN}/x86_64-unknown-linux-gnu-ld		CACHE PATH "linker")
set(CMAKE_AR 			${CLANG_TOOLCHAIN_BIN}/x86_64-unknown-linux-gnu-ar		CACHE PATH "archive")

# Include paths
set(CMAKE_SYSTEM_INCLUDE_PATH "")
set(CMAKE_INCLUDE_PATH  "")
# set(CMAKE_SYSROOT "${CLANG_TOOLCHAIN_ROOT}")
include_directories("${UE_THIRD_PARTY_PATH}/Unix/LibCxx/include/c++/v1")
include_directories("${CLANG_TOOLCHAIN_ROOT}/usr/include")

# Library paths (use libc++, specifically the one that comes with Unreal)
set(CMAKE_EXE_LINKER_FLAGS  "${CMAKE_EXE_LINKER_FLAGS} -stdlib=libc++")
link_directories("${UE_THIRD_PARTY_PATH}/Unix/LibCxx/lib/Unix/${LINUX_ARCH_NAME}")

# Compiler flags (chosen to match those Unreal uses as closely as possible)
set(CMAKE_CXX_EXTENSIONS OFF)
set(COMPILER_FLAGS " -fexceptions -DPLATFORM_EXCEPTIONS_DISABLED=0 -fmessage-length=0 \
                     -fpascal-strings -fasm-blocks -ffp-contract=off \
                     -fvisibility-inlines-hidden -fPIC --target=${LINUX_ARCH_NAME} -O3 -DNDEBUG \
                     --sysroot=${CLANG_TOOLCHAIN_ROOT} -fno-math-errno -fdiagnostics-format=msvc \
                     -funwind-tables -gdwarf-3 -pthread -Wno-unused-command-line-argument \
                     -Wno-error=deprecated-declarations -Wno-strict-prototypes -Wno-deprecated-copy \
                     -Wl,--allow-shlib-undefined")

string(CONCAT CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_INIT} ${COMPILER_FLAGS} ${CMAKE_CXX_FLAGS}")
string(CONCAT CMAKE_C_FLAGS   "${CMAKE_C_FLAGS_INIT}   ${COMPILER_FLAGS}")

set(CMAKE_CXX_CREATE_STATIC_LIBRARY	"<CMAKE_AR> rcs <TARGET> <LINK_FLAGS> <OBJECTS>" CACHE STRING "" FORCE)
