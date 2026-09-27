# Force ROS libraries to build against Unreal's Eigen, the same way FindOpenSSL.cmake in this
# directory forces Unreal's OpenSSL.
#
# Unreal ships Eigen as headers only, with no Eigen3Config.cmake, so find_package(Eigen3) in config
# mode cannot see it. Before the build was made hermetic, that gap was being filled by whatever
# Eigen the build machine had registered in the CMake package registry -- on this host, the
# Chocolatey Eigen 3.3.4 package. That is wrong twice over: it is not the Eigen that Unreal itself
# is compiled against (a real ABI hazard for anything passing Eigen types across the plugin
# boundary), and 3.3.4 still uses std::unary_negate/std::binary_negate, which C++20 removed.
# ROS's own eigen3_cmake_module carries a "Special case for Eigen 3.3.4 chocolatey package"
# workaround, which shows how routinely this bites.
#
# EIGEN3_INCLUDE_DIR is passed on the colcon command line and points at the copy of
# Engine/Source/ThirdParty/Eigen that the build script stages.

include(FindPackageHandleStandardArgs)

if(NOT EIGEN3_INCLUDE_DIR)
  find_package_handle_standard_args(Eigen3 REQUIRED_VARS EIGEN3_INCLUDE_DIR)
  return()
endif()

# Read the version out of the headers so downstream version checks behave.
set(_eigen3_macros "${EIGEN3_INCLUDE_DIR}/Eigen/src/Core/util/Macros.h")
if(EXISTS "${_eigen3_macros}")
  file(READ "${_eigen3_macros}" _eigen3_macros_content)
  string(REGEX MATCH "#define[ \t]+EIGEN_WORLD_VERSION[ \t]+([0-9]+)" _m "${_eigen3_macros_content}")
  set(EIGEN3_WORLD_VERSION "${CMAKE_MATCH_1}")
  string(REGEX MATCH "#define[ \t]+EIGEN_MAJOR_VERSION[ \t]+([0-9]+)" _m "${_eigen3_macros_content}")
  set(EIGEN3_MAJOR_VERSION "${CMAKE_MATCH_1}")
  string(REGEX MATCH "#define[ \t]+EIGEN_MINOR_VERSION[ \t]+([0-9]+)" _m "${_eigen3_macros_content}")
  set(EIGEN3_MINOR_VERSION "${CMAKE_MATCH_1}")
  set(EIGEN3_VERSION_STRING "${EIGEN3_WORLD_VERSION}.${EIGEN3_MAJOR_VERSION}.${EIGEN3_MINOR_VERSION}")
  unset(_eigen3_macros_content)
else()
  message(WARNING "Could not read Eigen version from ${_eigen3_macros}")
  set(EIGEN3_VERSION_STRING "3.4.0")
endif()
unset(_eigen3_macros)

# Both spellings: packages use EIGEN3_* and Eigen3_* more or less interchangeably, and
# ament_export_dependencies() wants the Eigen3_* ones.
set(EIGEN3_FOUND TRUE)
set(Eigen3_FOUND TRUE)
set(EIGEN3_INCLUDE_DIRS "${EIGEN3_INCLUDE_DIR}")
set(Eigen3_INCLUDE_DIR "${EIGEN3_INCLUDE_DIR}")
set(Eigen3_INCLUDE_DIRS "${EIGEN3_INCLUDE_DIR}")
set(EIGEN3_ROOT_DIR "${EIGEN3_INCLUDE_DIR}")
set(Eigen3_ROOT_DIR "${EIGEN3_INCLUDE_DIR}")
set(Eigen3_VERSION "${EIGEN3_VERSION_STRING}")
set(EIGEN3_VERSION "${EIGEN3_VERSION_STRING}")

# Modern consumers link the imported target and never look at the variables.
if(NOT TARGET Eigen3::Eigen)
  add_library(Eigen3::Eigen INTERFACE IMPORTED)
  set_target_properties(Eigen3::Eigen PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${EIGEN3_INCLUDE_DIR}")
endif()

find_package_handle_standard_args(Eigen3
  REQUIRED_VARS EIGEN3_INCLUDE_DIR
  VERSION_VAR EIGEN3_VERSION_STRING)
