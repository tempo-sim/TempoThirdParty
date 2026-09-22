#!/usr/bin/env bash

set -e

if [[ "$OSTYPE" != "msys" ]]; then
      echo "This script can only be run on Windows"
      exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR=$(realpath "$SCRIPT_DIR/..")

echo "Checking for prerequisites"

# Check for git
if ! which git; then
  echo "Couldn't find git"
  exit 1
fi

# Check for cmake
if ! which cmake; then
  echo "Couldn't find cmake"
  exit 1
fi

# Check for pip
if ! which pip; then
  echo "Couldn't find pip"
  exit 1
fi

# Check for cl
if ! which cl; then
  echo "Couldn't find cl. Please add C:\Program Files\Microsoft Visual Studio\<YOUR_RELEASE>\Community\VC\Tools\MSVC\<YOUR_VERSION>\bin\Hostx64\x64 to your PATH"
  exit 1
fi

# Check for tag. TAG can be set in the environment to build from an untagged
# commit, which is what the Jazzy upgrade work needs; release builds should
# still run from a tagged commit and get the tag from git.
if [ -z "${TAG+x}" ]; then
  TAG=$(git name-rev --tags --name-only "$(git rev-parse HEAD)")
  if [ "$TAG" = "undefined" ]; then
      echo "Could not find git tag. Set TAG=<name> to build from an untagged commit."
      exit 1
  fi
fi

# Check for UNREAL_ENGINE_PATH
if [ -z ${UNREAL_ENGINE_PATH+x} ]; then
  echo "UNREAL_ENGINE_PATH is not set";
  exit 1
fi

if [ ! -f "$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Win64/python311.dll" ]; then
  echo "Unreal's python3 is missing or unexpected version (expected 3.11)";
  exit 1
fi

UE_THIRD_PARTY_PATH="$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty"
if [ ! -d "${UE_THIRD_PARTY_PATH}" ]; then
  echo "ThirdParty directory does not exist: $UE_THIRD_PARTY_PATH";
  exit 1
fi

# Native (C:/...) forms for everything we hand to cmake.exe. UNREAL_ENGINE_PATH arrives as an MSYS
# path (/c/Program Files/...), and MSYS does not rewrite it inside the quoted "-DVAR='...'" strings
# we pass through colcon --cmake-args. CMake then stores the /c/... value verbatim and the setting
# silently does nothing: every -DZLIB_LIBRARY / -DPNG_LIBRARY / -DOPENSSL_* / -DPython3_LIBRARY we
# thought we were pinning was landing in the cache as an unusable path. That is why the OpenSSL
# pinning never actually took hold, and it only became a hard error in Jazzy, where lttngpy is the
# first package to require Python3 COMPONENTS Development.
#
# C:/... works fine in bash too, so the exported value is the native one -- cmake/Modules/*/
# FindOpenSSL.cmake reads it back out of the environment.
NATIVE_UNREAL_ENGINE_PATH=$(cygpath -m "$UNREAL_ENGINE_PATH")
NATIVE_UE_THIRD_PARTY_PATH=$(cygpath -m "$UE_THIRD_PARTY_PATH")
export UE_THIRD_PARTY_PATH="$NATIVE_UE_THIRD_PARTY_PATH"

echo -e "Using Unreal Engine ThirdParty: $UE_THIRD_PARTY_PATH\n";

echo -e "Using git tag: $TAG\n"

echo -e "All prerequisites satisfied. Starting build.\n"

BUILD_DIR="/c/rclbld"
INSTALL_DIR="$ROOT_DIR/Source/rclcpp/install"

# The Boost/ogg/vorbis/theora/OpenCV prelude takes hours and is independent of
# which ROS distro we are building. SKIP_PREBUILT=1 reuses whatever is already
# installed into Source/rclcpp/install and keeps the colcon build tree, which is
# what makes the patch/compile/fix loop workable. Release builds must not set it.
if [ -n "${SKIP_PREBUILT+x}" ]; then
  if [ ! -d "$INSTALL_DIR" ]; then
    echo "SKIP_PREBUILT is set but $INSTALL_DIR does not exist."
    echo "Run once without SKIP_PREBUILT to build the third party prelude first."
    exit 1
  fi
  echo -e "SKIP_PREBUILT is set: reusing prebuilt Boost/ogg/vorbis/theora/OpenCV.\n"
else
  echo -e "Removing stale Outputs and Builds\n"
  rm -rf "$ROOT_DIR/Outputs/rclcpp"
  rm -rf "$BUILD_DIR"
  rm -rf "$INSTALL_DIR"
  rm -rf "$ROOT_DIR/Source/rclcpp/log"
fi

mkdir -p $BUILD_DIR

NUM_JOBS=$(nproc --all)
echo -e "Detected $NUM_JOBS processors. Will use $NUM_JOBS jobs.\n"

# Tempo patches. The list lives in Scripts/patches.sh so the three platform
# scripts cannot drift apart again (they already had: yaml_cpp_vendor was
# applied on Windows only, and ros2cli.patch was applied nowhere).
#
# PATCH_TIERS selects which groups to apply:
#   B base (non-ROS third party)   E env (needed to build under Unreal)
#   R rtti / single process image  P std::pmr allocator conversion
# Override it to bisect a build, e.g. PATCH_TIERS=BE for stock ROS 2.
"$SCRIPT_DIR/patches.sh" apply --tier "${PATCH_TIERS:-BERP}"

# asio is a header-only copy, so it is cheap enough to refresh on every run -- and it must be,
# because Fast DDS version-checks asio/version.hpp. Leaving a stale copy behind SKIP_PREBUILT
# would silently keep an old asio in the prefix and fail the check.
echo -e "Copying asio"
rm -rf "$ROOT_DIR/Source/rclcpp/install/include/asio"
mkdir -p "$ROOT_DIR/Source/rclcpp/install/include/asio"
cp -r "$ROOT_DIR/Source/rclcpp/asio/asio/include/asio" "$ROOT_DIR/Source/rclcpp/install/include/asio/asio"
cp -r "$ROOT_DIR/Source/rclcpp/asio/asio/include/asio.hpp" "$ROOT_DIR/Source/rclcpp/install/include/asio"

# ---- third party prelude: Boost, ogg, vorbis, theora, OpenCV ----
# Hours of work that is identical across ROS distros, so SKIP_PREBUILT reuses it.
if [ -z "${SKIP_PREBUILT+x}" ]; then

echo -e "Building boost"
cd "$ROOT_DIR/Source/rclcpp/boost"
# You must run bootstrap separately with VS command prompt
if [ ! -f ./b2.exe ]; then
  echo "Please run ./bootstrap.bat --prefix=$ROOT_DIR/Source/rclcpp/install from a VS command prompt"
  exit 1
fi
#./bootstrap.bat --prefix="$ROOT_DIR/Source/rclcpp/install"
rm -rf bin.v2
./b2.exe install address-model=64 link=shared runtime-link=shared threading=multi --with-python --user-config="$ROOT_DIR/Source/rclcpp/boost_user_configs/boost-user-config-windows.jam" --prefix="$ROOT_DIR/Source/rclcpp/install"

echo -e "Building ogg"
mkdir -p "$BUILD_DIR/ogg"
cd "$BUILD_DIR/ogg"
cmake -G "Visual Studio 17 2022" "$ROOT_DIR/Source/rclcpp/ogg" -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Source/rclcpp/install"
cmake --build . -t install

echo -e "Building vorbis"
mkdir -p "$BUILD_DIR/vorbis"
cd "$BUILD_DIR/vorbis"
cmake -G "Visual Studio 17 2022" "$ROOT_DIR/Source/rclcpp/vorbis" -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Source/rclcpp/install"
cmake --build . -t install

echo -e "Building theora"
cd "$ROOT_DIR/Source/rclcpp/theora"
export OGG_LIBRARY_DIR="$ROOT_DIR/Source/rclcpp/install/lib"
export OGG_INCLUDE_DIR="$ROOT_DIR/Source/rclcpp/install/include"
msbuild.exe ./win32/VS2022/libtheora_dynamic.sln -p:Configuration=Release -p:Platform=x64
# Not sure how to install theora, so just copy the built files
find ./win32/VS2022/x64/Release -name "libtheora.*" -exec sh -c 'file=$1; dest=$2; filename=$(basename $1); cp "$file" "$dest/${filename#lib}"' sh {} "$ROOT_DIR/Source/rclcpp/install/lib" \;
mkdir -p "$ROOT_DIR/Source/rclcpp/install/include/theora"
cp ./include/theora/*.h "$ROOT_DIR/Source/rclcpp/install/include/theora"

echo -e "Building opencv"
mkdir -p "$BUILD_DIR/opencv"
cd "$BUILD_DIR/opencv"
cmake -G "Visual Studio 17 2022" \
 -DCMAKE_BUILD_TYPE=Release \
 -DBUILD_SHARED_LIBS=ON \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Source/rclcpp/install" \
 -DOPENCV_GENERATE_PKGCONFIG=ON \
 -DOPENCV_MAP_IMPORTED_CONFIG="RELWITHDEBINFO=Release;MINSIZEREL=Release" \
 -DBUILD_opencv_dnn=OFF \
 -DBUILD_PROTOBUF=OFF \
 -DBUILD_opencv_python3=OFF \
 -DBUILD_opencv_videoio=OFF \
 -DBUILD_opencv_datasets=OFF \
 -DBUILD_EXAMPLES=OFF \
 -DBUILD_PERF_TESTS=OFF \
 -DBUILD_TESTS=OFF \
 -DBUILD_TESTING=OFF \
 -DBUILD_opencv_apps=OFF \
 -DINSTALL_PYTHON_EXAMPLES=OFF \
 -DINSTALL_C_EXAMPLES=OFF \
 -DCMAKE_CXX_FLAGS="-D OPENCV_DISABLE_EIGEN_TENSOR_SUPPORT=1" \
 -DPYTHON_EXECUTABLE="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Win64/python.exe" \
 -DBUILD_opencv_python2=OFF \
 -DPYTHON3_EXECUTABLE="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Win64/python.exe" \
 -DPYTHON3_INCLUDE_DIR="$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/include" \
 -DPYTHON3_PACKAGES_PATH="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Win64" \
 "$ROOT_DIR/Source/rclcpp/opencv"
cmake --build . -t install --config Release -j "$NUM_JOBS"

fi
# ---- end third party prelude ----

# Remove the root-level "Windows Pack" OpenCVConfig, which is only a forwarder that guesses the
# runtime subdirectory from MSVC_VERSION. We point OpenCV_DIR straight at the real config instead.
rm -f "$ROOT_DIR/Source/rclcpp/install/OpenCVConfig.cmake" "$ROOT_DIR/Source/rclcpp/install/OpenCVConfig-version.cmake"

# On Windows OpenCV installs the real config (the one next to OpenCVModules.cmake) under
# <prefix>/<arch>/<runtime>/lib, e.g. install/x64/vc17/lib -- not install/lib as it does on Unix.
OPENCV_CMAKE_DIR=$(dirname "$(find "$ROOT_DIR/Source/rclcpp/install/x64" -name OpenCVConfig.cmake | head -1)")
if [ ! -f "$OPENCV_CMAKE_DIR/OpenCVModules.cmake" ]; then
  echo "Could not find the installed OpenCV cmake config under $ROOT_DIR/Source/rclcpp/install/x64"
  exit 1
fi
NATIVE_OPENCV_CMAKE_DIR=$(cygpath -m "$OPENCV_CMAKE_DIR")
echo -e "Using OpenCV cmake config: $NATIVE_OPENCV_CMAKE_DIR\n"

if [ ! -d "$BUILD_DIR/eigen-cp" ]; then
  cp -r "$UE_THIRD_PARTY_PATH/Eigen" "$BUILD_DIR/eigen-cp"
fi

# Unreal ships Eigen as headers with no Eigen3Config.cmake, so find_package(Eigen3 CONFIG) cannot
# see it. Several packages reach Eigen through ROS's eigen3_cmake_module, whose FindEigen3.cmake
# *only* does a config-mode find and then requires EIGEN3_FOUND -- our own Modules/Windows/
# FindEigen3.cmake never gets a look in, because eigen3_cmake_module puts its module directory
# ahead of ours. Generate the config package next to the headers instead, which satisfies config
# mode, module mode and the Eigen3::Eigen target for everyone.
#
# Until this existed the gap was being filled by whatever Eigen the machine had registered with
# CMake -- here, Chocolatey's Eigen 3.3.4 rather than the 3.4.0 Unreal is built against.
_eigen_macros="$BUILD_DIR/eigen-cp/Eigen/src/Core/util/Macros.h"
if [ ! -f "$_eigen_macros" ]; then
  echo "Could not find Eigen headers at $BUILD_DIR/eigen-cp"
  exit 1
fi
_eigen_world=$(grep -oP '#define\s+EIGEN_WORLD_VERSION\s+\K[0-9]+' "$_eigen_macros")
_eigen_major=$(grep -oP '#define\s+EIGEN_MAJOR_VERSION\s+\K[0-9]+' "$_eigen_macros")
_eigen_minor=$(grep -oP '#define\s+EIGEN_MINOR_VERSION\s+\K[0-9]+' "$_eigen_macros")
EIGEN_VERSION="$_eigen_world.$_eigen_major.$_eigen_minor"
echo -e "Using Unreal Eigen $EIGEN_VERSION\n"

cat > "$BUILD_DIR/eigen-cp/Eigen3Config.cmake" <<EOF
# Generated by build_rclcpp_windows.sh for Unreal's header-only Eigen. Do not edit.
get_filename_component(EIGEN3_INCLUDE_DIR "\${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
set(EIGEN3_INCLUDE_DIRS "\${EIGEN3_INCLUDE_DIR}")
set(EIGEN3_ROOT_DIR "\${EIGEN3_INCLUDE_DIR}")
set(Eigen3_INCLUDE_DIR "\${EIGEN3_INCLUDE_DIR}")
set(Eigen3_INCLUDE_DIRS "\${EIGEN3_INCLUDE_DIR}")
set(Eigen3_ROOT_DIR "\${EIGEN3_INCLUDE_DIR}")
set(EIGEN3_VERSION_STRING "$EIGEN_VERSION")
set(EIGEN3_VERSION "$EIGEN_VERSION")
set(Eigen3_VERSION "$EIGEN_VERSION")
set(EIGEN3_DEFINITIONS "")
set(EIGEN3_FOUND TRUE)
set(Eigen3_FOUND TRUE)
if(NOT TARGET Eigen3::Eigen)
  add_library(Eigen3::Eigen INTERFACE IMPORTED)
  set_target_properties(Eigen3::Eigen PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "\${EIGEN3_INCLUDE_DIR}")
endif()
EOF

cat > "$BUILD_DIR/eigen-cp/Eigen3ConfigVersion.cmake" <<EOF
# Generated by build_rclcpp_windows.sh. Do not edit.
set(PACKAGE_VERSION "$EIGEN_VERSION")
if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  if(PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
EOF

if [ ! -f "$BUILD_DIR/venv/Scripts/activate" ]; then
  echo -e "Creating Python virtual environment for colcon build.\n"
  cd "$UNREAL_ENGINE_PATH"
  ./Engine/Binaries/ThirdParty/Python3/Win64/python.exe -m venv "$BUILD_DIR/venv"
fi
source "$BUILD_DIR/venv/Scripts/activate"

# Run every time, not just on create: these are cheap no-ops once satisfied, and the venv now
# survives across runs when SKIP_PREBUILT is set, so a newly added dependency would otherwise
# never get installed into an existing environment.
pip install colcon-common-extensions
pip install empy==3.3.4
pip install lark==1.1.1
## numpy 2.x is an ABI break for rosidl_generator_py's extension modules and for
## cv_bridge, both of which are compiled against whatever numpy is present here.
pip install "numpy<2"
## New in Jazzy: ament_cmake_vendor_package's ament_vendor() shells out to "vcs" to fetch the
## sources it vendors (foonathan_memory, yaml-cpp, pybind11, orocos_kdl, mimick, ...). Humble used
## ExternalProject's own GIT_REPOSITORY and needed no such tool.
pip install vcstool
## 'pip install netifaces' builds from source, but Unreal's python config has a bunch of hard-coded
## paths to some engineer's machine, which makes that difficult. So we use this pre-compiled one for
## Python3.11 instead.
pip install "$ROOT_DIR/Source/rclcpp/netifaces/netifaces-0.11.0-cp311-cp311-win_amd64.whl"

echo "Building rclcpp..."
mkdir -p "$BUILD_DIR/Windows"
cd "$ROOT_DIR/Source/rclcpp"

mkdir -p "$ROOT_DIR/Outputs/rclcpp/Binaries/Windows"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Libraries/Windows"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Includes"

# To inspect compiler/linker commands
#export VERBOSE=1
# --event-handlers console_direct+ \
#  --parallel-workers "$NUM_JOBS" \
# " -DPython3_EXECUTABLE='$NATIVE_PYTHON_PATH'" \
# " -DCMAKE_POLICY_DEFAULT_CMP0025=NEW" \
# " -DCMAKE_CXX_FLAGS_DEBUG='/permissive- /volatile:iso /Zc:preprocessor /EHsc /Zc:__cplusplus /Zc:externConstexpr /Zc:throwingNew'" \
# " -DCMAKE_CXX_STANDARD_REQUIRED=ON" \
# " -DCMAKE_CXX_EXTENSIONS=OFF" \
# " -DBoost_NO_BOOST_CMAKE=ON" \
# CMake ships three separate Python find modules with three separate variable namespaces:
# FindPython3 (Python3_*), the deprecated FindPythonLibs/FindPythonInterp (PYTHON_*), and
# FindPython (Python_*). Which one a package uses is its own choice, so pin all three. PyKDL,
# reached through python_orocos_kdl_vendor's FetchContent, is the one that asks for plain
# find_package(Python COMPONENTS Development) and fails if only the other two are set.
#
# THIRDPARTY_Asio=FORCE / Asio_INCLUDE_DIR below is what Linux and Mac have always passed, and
# Windows never did. Without it Fast DDS does find_package(Asio CONFIG) first, which happily picks
# up whatever Asio the machine has installed -- on this build host, a Chocolatey asio 1.12.1, which
# is older than the 1.13.0 Fast DDS 2.14 requires, so the build fails on a package we vendor
# ourselves. FORCE skips the system search and uses the copy we install above.
#
# The ZLIB/PNG/JPEG settings below pass both the plural result variables and the singular *cache*
# variables (ZLIB_INCLUDE_DIR, PNG_PNG_INCLUDE_DIR, JPEG_INCLUDE_DIR). Only the singular ones are
# what CMake's Find modules actually look for; the plural ones are outputs those modules compute.
# Passing only the plural form looks right and does nothing, which went unnoticed until Jazzy added
# zstd_image_transport -- the first package here to call find_package(ZLIB) and therefore the first
# to fail on it.
#
# CMAKE_CXX_STANDARD stays at 17 here (Mac uses 20; that is a compiler difference, not drift).
# Jazzy is released and tested at C++17, and MSVC turns /permissive- on by default for /std:c++20,
# which then rejects rclcpp's own source: context.cpp defines Context::remove_shutdown_callback
# outside namespace rclcpp and names ShutdownCallbackHandle unqualified in the parameter list. The
# non-template overload right above it compiles fine; only the template trips MSVC's two-phase
# lookup. clang accepts both, which is why the Mac build has been on C++20 all along. Packages that
# genuinely need C++20 set it themselves, which is what the Tempo patches have always done.
#
# The three CMAKE_FIND_USE_* settings below make the build hermetic, which matters because this
# repo exists to produce a reproducible bundle and CMake will otherwise happily prefer whatever the
# build machine happens to have installed:
#
#  - SYSTEM_ENVIRONMENT_PATH: CMake derives a find_package prefix from every entry in PATH, and a
#    machine with the Tempo plugin deployed has the *shipped* bundle on PATH -- which contains
#    share/<pkg>/cmake/ configs, because packaging copies "share" into Binaries/Windows.
#    find_package(foonathan_memory) resolved against the previously released bundle.
#  - PACKAGE_REGISTRY / SYSTEM_PACKAGE_REGISTRY: HKCU/HKLM \Software\Kitware\CMake\Packages. On this
#    host Chocolatey had registered Asio, Bullet, CUnit, Eigen3, TinyXML and TinyXML2 there, so
#    find_package silently preferred those over the copies we vendor -- Asio 1.12.1 (too old for
#    Fast DDS 2.14) and Eigen 3.3.4 (which still uses std::unary_negate, removed in C++20) both
#    came from there, and tinyxml2 was being shadowed the same way without anyone noticing.
#
# Everything this build genuinely needs is either passed explicitly below or reachable through
# CMAKE_PREFIX_PATH, so none of those discovery mechanisms are load bearing. CMake derives a
# find_package search prefix from every entry in PATH, and a machine with the Tempo plugin deployed
# has the *shipped* bundle on PATH -- which contains share/<pkg>/cmake/ config files, because the
# packaging step copies "share" into Binaries/Windows. find_package(foonathan_memory) then resolves
# against the previously released bundle instead of the one we are building, and fails pointing at a
# lib/ directory that a runtime-only bundle does not have. Everything this build genuinely needs is
# passed explicitly or comes through CMAKE_PREFIX_PATH, so PATH-derived prefixes are pure contamination.
#
# cmake.exe is a native Windows program, so every path we hand it has to be a Windows path. MSYS only
# rewrites arguments it recognizes as paths, and it does not rewrite the quoted "-DVAR='...'" strings
# we pass through colcon's --cmake-args, so anything derived from $ROOT_DIR must be converted here.
# Getting this wrong fails silently: CMake stores the unusable /c/... value and then either reports
# the package as NOTFOUND or ignores the setting entirely.
NATIVE_ROOT_DIR=$(cygpath -m "$ROOT_DIR")
# -m, not -w: this value gets embedded in a CMake string that ament_vendor() re-parses with
# cmake_parse_arguments when forwarding it to the nested build, and a backslash path blows up
# there ("Invalid character escape '\e'" for C:\rclbld\eigen-cp). -m yields C:/... which CMake
# and MSVC both accept, and is what the rest of this script already uses.
NATIVE_EIGEN_PATH=$(cygpath -m "$BUILD_DIR/eigen-cp")
NATIVE_PYTHON_PATH=$(cygpath -w "$BUILD_DIR/venv/Scripts/python.exe")
# ament_vendor() does find_program(vcs_EXECUTABLE NAMES vcs), which searches PATH -- and we turn
# PATH searching off below to keep the build hermetic. Point it at the venv copy explicitly, the
# same way every other tool and library here is pinned rather than discovered.
NATIVE_VCS_PATH=$(cygpath -w "$BUILD_DIR/venv/Scripts/vcs.exe")
if [ ! -f "$BUILD_DIR/venv/Scripts/vcs.exe" ]; then
  echo "vcs was not installed into the build venv; ament_vendor() cannot fetch vendored sources."
  exit 1
fi

# Same story for pkg-config, which theora_image_transport uses via pkg_check_modules to find
# theora.pc/ogg.pc: find_program looks on PATH, and PATH searching is off.
PKG_CONFIG_BIN=$(which pkg-config 2>/dev/null)
if [ -z "$PKG_CONFIG_BIN" ]; then
  echo "Couldn't find pkg-config (expected a native Windows build, e.g. C:\\PkgConfig\\pkg-config.exe)"
  exit 1
fi
NATIVE_PKG_CONFIG_PATH=$(cygpath -m "$PKG_CONFIG_BIN")
# Every ament_vendor() package installs its payload to install/opt/<project> and then relies on an
# environment hook (share/<pkg>/environment/vendor_package_cmake_prefix.dsv, which says
# "prepend-non-duplicate;CMAKE_PREFIX_PATH;opt/<pkg>") to make that prefix findable. That hook is
# not taking effect in this build, so a package fails to find what the vendor package it depends on
# has just built -- lttngpy could not find pybind11, python_orocos_kdl_vendor could not find
# orocos_kdl, and so on for every vendor package. Rather than pin each one by hand, work out the
# vendor prefixes from the source tree and put them on CMAKE_PREFIX_PATH ourselves.
#
# Enumerating from the *source* tree matters: on a clean build install/opt is still empty at this
# point. Prefixes that do not exist yet are simply ignored by CMake, and by the time a dependent
# package configures, colcon has already built the vendor package it needs.
VENDOR_OPT_PREFIXES=""
while IFS= read -r _cml; do
  [ -z "$_cml" ] && continue
  _pname=$(grep -m1 -E '^[[:space:]]*project\(' "$_cml" | sed -E 's/^[[:space:]]*project\(([A-Za-z0-9_-]+).*/\1/')
  [ -n "$_pname" ] && VENDOR_OPT_PREFIXES="$VENDOR_OPT_PREFIXES;$NATIVE_ROOT_DIR/Source/rclcpp/install/opt/$_pname"
done <<< "$(grep -rlE '^[[:space:]]*ament_vendor\(' "$ROOT_DIR/Source/rclcpp" \
             --include=CMakeLists.txt --exclude-dir=install --exclude-dir=log --exclude-dir=build 2>/dev/null)"
echo -e "Vendor prefixes:$VENDOR_OPT_PREFIXES\n"

export CMAKE_PREFIX_PATH="$NATIVE_ROOT_DIR/Source/rclcpp/cmake;$NATIVE_EIGEN_PATH$VENDOR_OPT_PREFIXES"
# pkg-config here is a native Windows build (C:\PkgConfig\pkg-config.exe), so PKG_CONFIG_PATH needs
# Windows paths separated by ";" -- a "/c/..." entry is unreadable to it, and ":" would in any case
# split "C:/..." at the drive letter. This is what theora_image_transport's pkg_check_modules(theora)
# reads to find theora.pc/ogg.pc.
export PKG_CONFIG_PATH="$NATIVE_ROOT_DIR/Source/rclcpp/pkgconfig-windows;$PKG_CONFIG_PATH"
export VisualStudioVersion="17.8"
export OpenCV_DIR="$NATIVE_OPENCV_CMAKE_DIR"
# Pass Unreal's OpenSSL explicitly, the same way zlib/libPNG/libJPG are passed below. Modules/Windows/
# FindOpenSSL.cmake is supposed to force this via CMAKE_MODULE_PATH, but as of v0.16 it was not taking
# effect for CycloneDDS or Fast-DDS: ddsc.dll and fastrtps-2.6.dll shipped importing the build machine's
# libssl-1_1-x64.dll/libcrypto-1_1-x64.dll, which no Unreal install provides (tempo-sim/TempoROS#71).
# A missed CMAKE_MODULE_PATH fails silently, because find_package(OpenSSL) then falls back to CMake's
# builtin module and happily finds a system OpenSSL. These cache entries pin the static Unreal libs
# whether or not our FindOpenSSL.cmake is the one that gets loaded.
colcon build --packages-skip-by-dep python_qt_binding --packages-skip Boost OpenCV libogg vorbis iceoryx \
 --build-base "$BUILD_DIR/Windows" \
 --merge-install \
 --catkin-skip-building-tests \
 --parallel-workers "$NUM_JOBS" \
 --event-handlers desktop_notification- \
 --cmake-clean-cache \
 --cmake-args \
 " -G Visual Studio 17 2022" \
 " -DCMAKE_CXX_STANDARD=17" \
 " -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF" \
 " -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF" \
 " -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF" \
 " -Dvcs_EXECUTABLE='$NATIVE_VCS_PATH'" \
 " -DPKG_CONFIG_EXECUTABLE='$NATIVE_PKG_CONFIG_PATH'" \
 " -DAsio_INCLUDE_DIR='$NATIVE_ROOT_DIR/Source/rclcpp/install/include/asio'" \
 " -DTHIRDPARTY_Asio=FORCE" \
 " -DBUILD_SHARED_LIBS=ON" \
 " -DBUILD_TESTS=OFF" \
 " -DBUILD_TESTING=OFF" \
 " -DEIGEN3_INCLUDE_DIR='$NATIVE_EIGEN_PATH'" \
 " -DCMAKE_C_COMPILER_WORKS=ON" \
 " -DCMAKE_CXX_COMPILER_WORKS=ON" \
 " -DZLIB_LIBRARY='$NATIVE_UE_THIRD_PARTY_PATH/zlib/1.3/lib/Win64/Release/zlibstatic.lib'" \
 " -DZLIB_LIBRARIES='$NATIVE_UE_THIRD_PARTY_PATH/zlib/1.3/lib/Win64/Release/zlibstatic.lib'" \
 " -DZLIB_INCLUDE_DIRS='$NATIVE_UE_THIRD_PARTY_PATH/zlib/1.3/include'" \
 " -DZLIB_INCLUDE_DIR='$NATIVE_UE_THIRD_PARTY_PATH/zlib/1.3/include'" \
 " -DZLIB_USE_STATIC_LIBS=ON" \
 " -DZLIB_FOUND=ON" \
 " -DPNG_INCLUDE_DIRS='$NATIVE_UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44'" \
 " -DPNG_PNG_INCLUDE_DIRS='$NATIVE_UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44'" \
 " -DPNG_PNG_INCLUDE_DIR='$NATIVE_UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44'" \
 " -DPNG_LIBRARIES='$NATIVE_UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44/lib/Win64/x64/Release/libpng.lib'" \
 " -DPNG_LIBRARY='$NATIVE_UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44/lib/Win64/x64/Release/libpng.lib'" \
 " -DPNG_FOUND=ON" \
 " -DJPEG_INCLUDE_DIRS='$NATIVE_UE_THIRD_PARTY_PATH/libJPG'" \
 " -DJPEG_INCLUDE_DIR='$NATIVE_UE_THIRD_PARTY_PATH/libJPG'" \
 " -DOPENCV_MAP_IMPORTED_CONFIG='RELWITHDEBINFO=Release;MINSIZEREL=Release'" \
 " -DOpenCV_DIR='$NATIVE_OPENCV_CMAKE_DIR'" \
 " -DBOOST_ROOT='$NATIVE_ROOT_DIR/Source/rclcpp/install'" \
 " -DBoost_NO_SYSTEM_PATHS=ON" \
 " -DBoost_USE_STATIC_LIBS=OFF" \
 " -Dtinyxml2_SHARED_LIBS=ON" \
 " -DTHREADS_PREFER_PTHREAD_FLAG=ON" \
 " -DSM_RUN_RESULT=0" \
 " -DSM_RUN_RESULT__TRYRUN_OUTPUT=''" \
 " -DCMAKE_MODULE_PATH='$NATIVE_ROOT_DIR/Source/rclcpp/cmake/Modules/Windows'" \
 " -DOPENSSL_USE_STATIC_LIBS=ON" \
 " -DOPENSSL_ROOT_DIR='$NATIVE_UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t'" \
 " -DOPENSSL_INCLUDE_DIR='$NATIVE_UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/include/Win64/VS2015'" \
 " -DOPENSSL_CRYPTO_LIBRARY='$NATIVE_UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libcrypto.lib'" \
 " -DOPENSSL_SSL_LIBRARY='$NATIVE_UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libssl.lib'" \
 " -DCMAKE_POLICY_DEFAULT_CMP0144=NEW" \
 " -DTRACETOOLS_DISABLED=ON" \
 " -DFORCE_BUILD_VENDOR_PKG=ON" \
 " -DPython3_LIBRARY='$NATIVE_UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/libs/python311.lib'" \
 " -DPython3_INCLUDE_DIR='$NATIVE_UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/include'" \
 " -DPYTHON_EXECUTABLE='$NATIVE_PYTHON_PATH'" \
 " -DPYTHON_LIBRARY='$NATIVE_UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/libs/python311.lib'" \
 " -DPYTHON_INCLUDE_DIR='$NATIVE_UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/include'" \
 " -DPython_EXECUTABLE='$NATIVE_PYTHON_PATH'" \
 " -DPython_LIBRARY='$NATIVE_UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/libs/python311.lib'" \
 " -DPython_INCLUDE_DIR='$NATIVE_UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/include'" \
 " --no-warn-unused-cli"

DEST="$ROOT_DIR/Outputs/rclcpp"

# Copy the binaries.
# theora.dll and boost_python*.dll are named explicitly because they land in install/lib: the
# theora prelude copies the DLL there by hand, and b2 installs Boost's runtime alongside its import
# libraries. Everything CMake installs puts its DLL in install/bin (RUNTIME) and only the import
# library in install/lib (ARCHIVE), so those are covered by the bin/* copy below -- tf2_eigen_kdl
# used to be listed here as well, which broke the build the moment it was not in install/lib.
cp -r -P "$ROOT_DIR/Source/rclcpp/install/lib/theora.dll" "$DEST/Binaries/Windows/libtheora.dll"
cp -r -P "$ROOT_DIR/Source/rclcpp/install/lib/boost_python311-"*".dll" "$DEST/Binaries/Windows"
cp -r -P "$ROOT_DIR/Source/rclcpp/install/bin"/* "$DEST/Binaries/Windows"
cp -r -P "$ROOT_DIR/Source/rclcpp/install/Scripts"/* "$DEST/Binaries/Windows"

# Vendor packages (yaml_cpp_vendor, etc) install to their own prefix under install/opt rather than
# install/bin, so the copy above misses them. Search the whole install tree, the way the Mac and
# Linux scripts do for dylibs/sos. Without this, yaml-cpp.lib ships (the *.lib find below is already
# recursive) but yaml-cpp.dll does not, and camera_calibration_parsers.dll fails to load at runtime.
find "$ROOT_DIR/Source/rclcpp/install" -name "*.dll" -exec cp -P {} "$DEST/Binaries/Windows" \;

# Copy the libraries
find "$ROOT_DIR/Source/rclcpp/install" -name "*.lib" -exec cp -P {} "$DEST/Libraries/Windows" \;

# Copy the Python deps
mkdir -p "$DEST/Libraries/Windows/python3.11"
cp -r -P "$ROOT_DIR/Source/rclcpp/install/lib/site-packages" "$DEST/Libraries/Windows/python3.11"

# Copy the Python deps from the virtual environment
cp -r -P "$BUILD_DIR/venv/Lib/site-packages" "$DEST/Libraries/Windows/python3.11"

# Copy the "share" folder
cp -r -P "$ROOT_DIR/Source/rclcpp/install/share" "$DEST/Binaries/Windows"

# Copy the includes
INCLUDE_DIRS=$(find "$ROOT_DIR/Source/rclcpp/install/include" -maxdepth 1 -mindepth 1 -type d)
for INCLUDE_DIR in $INCLUDE_DIRS; do
  LIBRARY_NAME=$(basename "$INCLUDE_DIR")
  if [ -e "$INCLUDE_DIR/$LIBRARY_NAME" ]; then
    cp -r "$INCLUDE_DIR"/* "$DEST/Includes"
  else
    cp -r "$INCLUDE_DIR" "$DEST/Includes"
  fi
done

echo -e "Archiving outputs...\n"
RCLCPP_ARCHIVE="$ROOT_DIR/Releases/TempoThirdParty-rclcpp-Windows-$TAG.tar.gz"
rm -rf "$RCLCPP_ARCHIVE"
tar -C "$ROOT_DIR/Outputs" -czf "$RCLCPP_ARCHIVE" rclcpp

echo "Done! Archives: $RCLCPP_ARCHIVE"
