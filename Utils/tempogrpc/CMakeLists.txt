# Copyright Tempo Simulation, LLC. All Rights Reserved

# Links the gRPC, Protobuf and Abseil static libraries into one shared library, tempogrpc.
#
# Those libraries keep global state (Protobuf's descriptor pool, gRPC's core, Abseil's flags), so a
# process must hold exactly one copy of them, which every module that uses them then shares. This
# library is that copy. It takes the static libraries whole, so it defines everything a module could
# refer to, and it links the Unreal Engine's OpenSSL and zlib, which the static libraries were built
# against.
#
# Configure with:
#   -DTEMPO_GRPC_OUTPUT_DIR=<TempoThirdParty>/Outputs/gRPC     where the static libraries were installed
#   -DTEMPO_GRPC_PLATFORM=Mac|Linux|Windows                    the Libraries/<Platform> to link
#   -DUE_THIRD_PARTY_PATH=<UnrealEngine>/Engine/Source/ThirdParty
# and install with CMAKE_INSTALL_PREFIX set to TEMPO_GRPC_OUTPUT_DIR: the library goes beside the
# static libraries (Libraries/<Platform>), and on Windows the DLL goes to Binaries/Windows.

cmake_minimum_required(VERSION 3.20)
project(tempogrpc CXX)

set(LIBRARIES_DIR "${TEMPO_GRPC_OUTPUT_DIR}/Libraries/${TEMPO_GRPC_PLATFORM}")
file(GLOB STATIC_LIBRARIES "${LIBRARIES_DIR}/*${CMAKE_STATIC_LIBRARY_SUFFIX}")
list(SORT STATIC_LIBRARIES)
if(NOT STATIC_LIBRARIES)
  message(FATAL_ERROR "No static libraries found in ${LIBRARIES_DIR}")
endif()

add_library(tempogrpc SHARED tempogrpc.cpp)

if(WIN32)
  # The linker only takes from a static library what something refers to, and /WHOLEARCHIVE does
  # not reliably change that. exports.def names every symbol of every static library, so given it
  # the linker takes them all, and exports them.
  target_sources(tempogrpc PRIVATE "${LIBRARIES_DIR}/exports.def")
  # A symbol the .def file names and a library also exports on its own is reported as specified
  # twice, which is harmless.
  target_link_options(tempogrpc PRIVATE /IGNORE:4197)
  target_link_libraries(tempogrpc PRIVATE
    ${STATIC_LIBRARIES}
    "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libssl.lib"
    "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libcrypto.lib"
    "${UE_THIRD_PARTY_PATH}/zlib/1.3/lib/Win64/Release/zlibstatic.lib"
    ws2_32 crypt32)
else()
  # On Mac and Linux exports.def names the static libraries to take whole. The rest repeat symbols
  # of those, and are only searched for what is still missing.
  file(STRINGS "${LIBRARIES_DIR}/exports.def" WHOLE_LIBRARIES)
  list(TRANSFORM WHOLE_LIBRARIES STRIP)
  set(WHOLE_STATIC_LIBRARIES)
  set(SEARCHED_STATIC_LIBRARIES)
  foreach(STATIC_LIBRARY ${STATIC_LIBRARIES})
    get_filename_component(STATIC_LIBRARY_NAME "${STATIC_LIBRARY}" NAME)
    if(STATIC_LIBRARY_NAME IN_LIST WHOLE_LIBRARIES)
      if(APPLE)
        target_link_options(tempogrpc PRIVATE "LINKER:-force_load,${STATIC_LIBRARY}")
      else()
        list(APPEND WHOLE_STATIC_LIBRARIES "${STATIC_LIBRARY}")
      endif()
    else()
      list(APPEND SEARCHED_STATIC_LIBRARIES "${STATIC_LIBRARY}")
    endif()
  endforeach()
  if(WHOLE_STATIC_LIBRARIES)
    # One group, passed as libraries rather than options: libraries go in the linker's response file,
    # while options go on the command line, which for this many paths outgrows cmd.exe's 8191
    # character limit when cross-compiling from Windows. It comes before the searched libraries, so
    # they can supply what it is still missing.
    target_link_libraries(tempogrpc PRIVATE
      "-Wl,--whole-archive" ${WHOLE_STATIC_LIBRARIES} "-Wl,--no-whole-archive")
  endif()
  target_link_libraries(tempogrpc PRIVATE ${SEARCHED_STATIC_LIBRARIES})

  if(APPLE)
    target_link_libraries(tempogrpc PRIVATE
      "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/lib/Mac/libssl.a"
      "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/lib/Mac/libcrypto.a"
      "${UE_THIRD_PARTY_PATH}/zlib/1.3/lib/Mac/Release/libz.a"
      "-framework CoreFoundation" "-framework Security" resolv)
  else()
    # Linked the way Unreal links a module: its own static libc++, nothing else from the compiler.
    target_link_options(tempogrpc PRIVATE -nostdlib++
      # Every symbol has to come from somewhere here; report at link time rather than at load time.
      LINKER:--no-undefined
      # A few of the libraries taken whole define the same symbol. Any of the definitions will do.
      LINKER:--allow-multiple-definition)
    target_link_libraries(tempogrpc PRIVATE
      "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/lib/Unix/${LINUX_ARCH_NAME}/libssl.a"
      "${UE_THIRD_PARTY_PATH}/OpenSSL/1.1.1t/lib/Unix/${LINUX_ARCH_NAME}/libcrypto.a"
      "${UE_THIRD_PARTY_PATH}/zlib/1.3/lib/Unix/${LINUX_ARCH_NAME}/Release/libz.a"
      pthread dl rt m)
  endif()
endif()

install(TARGETS tempogrpc
  RUNTIME DESTINATION "Binaries/${TEMPO_GRPC_PLATFORM}"
  LIBRARY DESTINATION "Libraries/${TEMPO_GRPC_PLATFORM}"
  ARCHIVE DESTINATION "Libraries/${TEMPO_GRPC_PLATFORM}")
