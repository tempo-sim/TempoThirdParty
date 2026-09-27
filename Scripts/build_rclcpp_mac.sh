#!/usr/bin/env bash

set -e

if [[ "$OSTYPE" != "darwin"* ]]; then
      echo "This script can only be run on Mac"
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

# Check for brew
if ! which brew; then
  echo "Couldn't find brew"
  exit 1
fi

# Check for autoconf
if ! brew ls autoconf; then
    echo "Couldn't find autoconf. Please install (brew install autoconf)."
    exit 1
fi

# Check for automake
if ! brew ls automake; then
    echo "Couldn't find automake. Please install (brew install automake)."
    exit 1
fi

# Check for libtool
if ! brew ls libtool; then
    echo "Couldn't find libtool. Please install (brew install libtool)."
    exit 1
fi

# Check for tag. TAG can be set in the environment to build from an untagged
# commit; release builds should still run from a tagged commit.
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

if [ ! -d "$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/lib/python3.11" ]; then
  echo "Unreal's python3 is missing or unexpected version (expected 3.11)";
  exit 1
fi

UE_THIRD_PARTY_PATH="$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty"
if [ ! -d "${UE_THIRD_PARTY_PATH}" ]; then
  echo "ThirdParty directory does not exist: $UE_THIRD_PARTY_PATH";
  exit 1
fi
export UE_THIRD_PARTY_PATH="$UE_THIRD_PARTY_PATH"

# Unreal bumps its zlib and libPNG versions between engine releases (5.6 shipped zlib 1.2.13 and
# libPNG-1.5.27, 5.7/5.8 ship zlib 1.3 and libPNG-1.6.44) and libpng.a moved into a Release
# subdirectory along the way. Discover both rather than hard-coding paths that only match one engine.
ZLIB_ROOT=$(find "$UE_THIRD_PARTY_PATH/zlib" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)
ZLIB_LIBRARY="$ZLIB_ROOT/lib/Mac/Release/libz.a"
if [ ! -f "$ZLIB_LIBRARY" ]; then
  ZLIB_LIBRARY="$ZLIB_ROOT/lib/Mac/libz.a"
fi
if [ ! -f "$ZLIB_LIBRARY" ] || [ ! -f "$ZLIB_ROOT/include/zlib.h" ]; then
  echo "Couldn't find Unreal's zlib for Mac under $UE_THIRD_PARTY_PATH/zlib";
  exit 1
fi

PNG_ROOT=$(find "$UE_THIRD_PARTY_PATH/libPNG" -mindepth 1 -maxdepth 1 -type d -name "libPNG-*" | sort -V | tail -1)
PNG_LIBRARY="$PNG_ROOT/lib/Mac/Release/libpng.a"
if [ ! -f "$PNG_LIBRARY" ]; then
  PNG_LIBRARY="$PNG_ROOT/lib/Mac/libpng.a"
fi
if [ ! -f "$PNG_LIBRARY" ] || [ ! -f "$PNG_ROOT/png.h" ]; then
  echo "Couldn't find Unreal's libPNG for Mac under $UE_THIRD_PARTY_PATH/libPNG";
  exit 1
fi

echo -e "Using Unreal zlib: $ZLIB_LIBRARY";
echo -e "Using Unreal libPNG: $PNG_LIBRARY";

echo -e "Using Unreal Engine ThirdParty: $UE_THIRD_PARTY_PATH\n";

echo -e "Using git tag: $TAG\n"

echo -e "All prerequisites satisfied. Starting build.\n"

INSTALL_DIR="$ROOT_DIR/Source/rclcpp/install"

# The Boost/ogg/theora/OpenCV prelude is independent of which ROS distro we are building.
# SKIP_PREBUILT=1 reuses whatever is already installed into Source/rclcpp/install and keeps the
# colcon build tree, which is what makes the patch/compile/fix loop workable. Release builds must
# not set it.
if [ -n "${SKIP_PREBUILT+x}" ]; then
  if [ ! -d "$INSTALL_DIR" ]; then
    echo "SKIP_PREBUILT is set but $INSTALL_DIR does not exist."
    echo "Run once without SKIP_PREBUILT to build the third party prelude first."
    exit 1
  fi
  echo -e "SKIP_PREBUILT is set: reusing prebuilt Boost/ogg/theora/OpenCV.\n"
  rm -rf "$ROOT_DIR/Outputs/rclcpp"
else
  echo -e "Removing stale Outputs and Builds\n"
  rm -rf "$ROOT_DIR/Outputs/rclcpp"
  rm -rf "$ROOT_DIR/Builds/rclcpp"
  rm -rf "$INSTALL_DIR"
  rm -rf "$ROOT_DIR/Source/rclcpp/log"
fi

NUM_JOBS="$(sysctl -n hw.ncpu)"
echo -e "Detected $NUM_JOBS processors. Will use $NUM_JOBS jobs.\n"

# Tempo patches. The list lives in Scripts/patches.sh so the three platform
# scripts cannot drift apart again (they already had: yaml_cpp_vendor was
# applied on Windows only, and ros2cli.patch was applied nowhere). opencv.patch
# stays Mac-only and patches.sh knows that.
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

# ---- third party prelude: Boost, ogg, theora, OpenCV ----
# Identical across ROS distros, so SKIP_PREBUILT reuses it.
if [ -z "${SKIP_PREBUILT+x}" ]; then

echo -e "Building boost"
cd "$ROOT_DIR/Source/rclcpp/boost"
rm -rf bin.v2
./bootstrap.sh --prefix="$ROOT_DIR/Source/rclcpp/install"
./b2 install --with-python --user-config="$ROOT_DIR/Source/rclcpp/boost_user_configs/boost-user-config-mac.jam" -d0 \
 cflags=-mmacosx-version-min=10.15 cxxflags=-mmacosx-version-min=10.15 mflags=-mmacosx-version-min=10.15 mmflags=-mmacosx-version-min=10.15 linkflags=-mmacosx-version-min=10.15

export CFLAGS="-mmacosx-version-min=10.15"
export CPPFLAGS="-mmacosx-version-min=10.15"

echo -e "Building ogg"
cd "$ROOT_DIR/Source/rclcpp/ogg"
./autogen.sh
./configure --prefix="$ROOT_DIR/Source/rclcpp/install"
make clean
make install

echo -e "Building theora"
cd "$ROOT_DIR/Source/rclcpp/theora"
# theora resolves libogg through pkg-config, not --with-ogg, so without our install prefix on
# PKG_CONFIG_PATH it silently links Homebrew's libogg - a dependency no user's machine has.
THEORA_PKG_CONFIG_PATH="$ROOT_DIR/Source/rclcpp/install/lib/pkgconfig:$PKG_CONFIG_PATH"
PKG_CONFIG_PATH="$THEORA_PKG_CONFIG_PATH" ./autogen.sh
PKG_CONFIG_PATH="$THEORA_PKG_CONFIG_PATH" ./configure --prefix="$ROOT_DIR/Source/rclcpp/install" --with-ogg="$ROOT_DIR/Source/rclcpp/install" --disable-examples
make clean
make install

echo -e "Building opencv"
mkdir -p "$ROOT_DIR/Builds/rclcpp/opencv"
cd "$ROOT_DIR/Builds/rclcpp/opencv"
cmake \
 -DCMAKE_BUILD_TYPE=RELEASE \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Source/rclcpp/install" \
 -DOPENCV_GENERATE_PKGCONFIG=ON \
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
 -DPYTHON_EXECUTABLE="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/bin/python3" \
 -DBUILD_opencv_python2=OFF \
 -DPYTHON3_EXECUTABLE="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/bin/python3" \
 -DPYTHON3_INCLUDE_DIR="$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include" \
 -DPYTHON3_PACKAGES_PATH="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac" \
 -DCMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
 "$ROOT_DIR/Source/rclcpp/opencv"
cmake --build . -t install -j "$NUM_JOBS"

fi
# ---- end third party prelude ----

if [ ! -f "$ROOT_DIR/Builds/rclcpp/venv/bin/activate" ]; then
  echo -e "Creating Python virtual environment for colcon build.\n"
  cd "$UNREAL_ENGINE_PATH"
  ./Engine/Binaries/ThirdParty/Python3/Mac/bin/python3 -m venv "$ROOT_DIR/Builds/rclcpp/venv"
fi
source "$ROOT_DIR/Builds/rclcpp/venv/bin/activate"
# Run every time, not just on create: these are cheap no-ops once satisfied, and the venv
# survives across runs when SKIP_PREBUILT is set, so a newly added dependency would otherwise
# never get installed into an existing environment.
pip install colcon-common-extensions
pip install empy==3.3.4
pip install lark==1.1.1
# numpy 2.x is an ABI break for rosidl_generator_py's extension modules and for
# cv_bridge, both of which are compiled against whatever numpy is present here.
pip install "numpy<2"
# New in Jazzy: ament_cmake_vendor_package's ament_vendor() shells out to "vcs" to fetch the
# sources it vendors (foonathan_memory, yaml-cpp, pybind11, orocos_kdl, mimick, ...). Humble used
# ExternalProject's own GIT_REPOSITORY and needed no such tool.
pip install vcstool
# 'pip install netifaces' builds from source, but Unreal's python config has a bunch of hard-coded
# paths to some engineer's machine, which makes that difficult. So we use this pre-compiled one for
# Python3.11 instead.
pip install "$ROOT_DIR/Source/rclcpp/netifaces/netifaces-0.11.0-cp311-cp311-macosx_10_9_universal2.whl"

echo "Building rclcpp..."
mkdir -p "$ROOT_DIR/Builds/rclcpp/Mac"
cd "$ROOT_DIR/Source/rclcpp"

mkdir -p "$ROOT_DIR/Outputs/rclcpp/Binaries/Mac"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Includes"

# CMake ships three separate Python find modules with three separate variable namespaces:
# FindPython3 (Python3_*), the deprecated FindPythonLibs/FindPythonInterp (PYTHON_*), and
# FindPython (Python_*). Which one a package uses is its own choice, so pin all three to the venv
# (which is Unreal's Python 3.11). *_FIND_FRAMEWORK=NEVER matters on Mac: FindPython searches
# framework installs before anything else by default, so tf2_py -- which calls
# find_package(Python3 COMPONENTS Development) without going through PythonExtra first -- picked up
# Homebrew's /opt/homebrew/Frameworks/Python.framework 3.13 and then failed to find its headers.
#
# To inspect compiler/linker commands
# export VERBOSE=1
# --cmake-clean-cache \
# --event-handlers console_direct+ \
export PKG_CONFIG_PATH="$ROOT_DIR/Source/rclcpp/pkgconfig:$PKG_CONFIG_PATH"
colcon build --packages-skip-by-dep python_qt_binding --packages-skip Boost OpenCV libogg vorbis iceoryx \
 --build-base "$ROOT_DIR/Builds/rclcpp/Mac" \
 --merge-install \
 --catkin-skip-building-tests \
 --parallel-workers "$NUM_JOBS" \
 --event-handlers console_direct+ \
 --cmake-args \
 " -DCMAKE_CXX_STANDARD=20" \
 " -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF" \
 " -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF" \
 " -Dvcs_EXECUTABLE='$ROOT_DIR/Builds/rclcpp/venv/bin/vcs'" \
 " -DAsio_INCLUDE_DIR=$ROOT_DIR/Source/rclcpp/install/include/asio" \
 " -DTHIRDPARTY_Asio=FORCE" \
 " -DBUILD_TESTS=OFF" \
 " -DBUILD_TESTING=OFF" \
 " -DZLIB_LIBRARY='$ZLIB_LIBRARY'" \
 " -DZLIB_LIBRARIES='$ZLIB_LIBRARY'" \
 " -DZLIB_INCLUDE_DIRS='$ZLIB_ROOT/include'" \
 " -DZLIB_INCLUDE_DIR='$ZLIB_ROOT/include'" \
 " -DZLIB_USE_STATIC_LIBS=ON" \
 " -DZLIB_FOUND=ON" \
 " -DPNG_INCLUDE_DIRS='$PNG_ROOT'" \
 " -DPNG_PNG_INCLUDE_DIRS='$PNG_ROOT'" \
 " -DPNG_PNG_INCLUDE_DIR='$PNG_ROOT'" \
 " -DPNG_LIBRARIES='$PNG_LIBRARY'" \
 " -DPNG_LIBRARY='$PNG_LIBRARY'" \
 " -DPNG_FOUND=ON" \
 " -DJPEG_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/libJPG'" \
 " -DOpenCV_DIR='$ROOT_DIR/Builds/rclcpp/opencv'" \
 " -DBOOST_ROOT='$ROOT_DIR/Source/rclcpp/install'" \
 " -DBoost_NO_SYSTEM_PATHS=ON" \
 " -Dtinyxml2_SHARED_LIBS=ON" \
 " -DTHREADS_PREFER_PTHREAD_FLAG=ON" \
 " -DSM_RUN_RESULT=0" \
 " -DSM_RUN_RESULT__TRYRUN_OUTPUT=''" \
 " -DCMAKE_MODULE_PATH='$ROOT_DIR/Source/rclcpp/cmake/Modules/Mac'" \
 " -DCMAKE_POLICY_DEFAULT_CMP0148=OLD" \
 " -DCMAKE_POLICY_DEFAULT_CMP0074=OLD" \
 " -DCMAKE_POLICY_DEFAULT_CMP0144=NEW" \
 " -DCMAKE_INSTALL_RPATH='@loader_path;@executable_path/../UE/Engine/Binaries/ThirdParty/Python3/Mac'" \
 " -DCMAKE_OSX_ARCHITECTURES=arm64" \
 " -DTRACETOOLS_DISABLED=ON" \
 " -DBoost_NO_BOOST_CMAKE=ON" \
 " -DFORCE_BUILD_VENDOR_PKG=ON" \
 " -DPython3_EXECUTABLE='$ROOT_DIR/Builds/rclcpp/venv/bin/python3'" \
 " -DPython3_LIBRARY='$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/libpython3.11.dylib'" \
 " -DPython3_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include'" \
 " -DPython3_FIND_FRAMEWORK=NEVER" \
 " -DPython_EXECUTABLE='$ROOT_DIR/Builds/rclcpp/venv/bin/python3'" \
 " -DPython_LIBRARY='$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/libpython3.11.dylib'" \
 " -DPython_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include'" \
 " -DPython_FIND_FRAMEWORK=NEVER" \
 " -DPYTHON_EXECUTABLE='$ROOT_DIR/Builds/rclcpp/venv/bin/python3'" \
 " -DPythonExtra_INCLUDE_DIRS='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include'" \
 " -DPythonExtra_LIBRARIES='$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/libpython3.11.dylib'" \
 " -DPYTHON_LIBRARY='$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/libpython3.11.dylib'" \
 " -DPYTHON_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include'" \
 " -DCMAKE_CXX_FLAGS=-isystem '$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include' -mmacosx-version-min=10.15 -Wno-unused-command-line-argument -Wno-error=unused-command-line-argument" \
 " -DCMAKE_C_FLAGS=-isystem '$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include' -mmacosx-version-min=10.15 -Wno-unused-command-line-argument -Wno-error=unused-command-line-argument" \
 " --no-warn-unused-cli"

DEST="$ROOT_DIR/Outputs/rclcpp"

# Copy the binaries
cp -r -P "$ROOT_DIR/Source/rclcpp/install/bin"/* "$DEST/Binaries/Mac"

# Copy the libraries
find "$ROOT_DIR/Source/rclcpp/install" -name "*.dylib" -exec cp -P {} "$DEST/Libraries/Mac" \;

# The CMake packages get relocatable install names from CMAKE_INSTALL_RPATH above, but the
# autotools-built ogg and theora libraries bake in absolute paths to the build machine's install
# prefix, so they only load on the machine that built them. Everything lands in one flat directory
# here, so point every non-system reference at @loader_path. install_name_tool invalidates the
# code signature, hence the re-sign.
echo -e "Making dylib references relocatable"
for DYLIB in "$DEST/Libraries/Mac"/*.dylib; do
  CHANGED=0
  DYLIB_ID=$(otool -D "$DYLIB" | tail -n +2)
  case "$DYLIB_ID" in
    /*) install_name_tool -id "@rpath/$(basename "$DYLIB_ID")" "$DYLIB"; CHANGED=1 ;;
  esac
  for DEP in $(otool -L "$DYLIB" | tail -n +2 | awk '{print $1}'); do
    case "$DEP" in
      @*|/usr/lib/*|/System/*) ;;
      /*) install_name_tool -change "$DEP" "@loader_path/$(basename "$DEP")" "$DYLIB"; CHANGED=1 ;;
    esac
  done
  if [ "$CHANGED" = "1" ]; then
    codesign --force --sign - "$DYLIB"
  fi
done

# Copy the Python deps from the virtual environment
cp -r -P "$ROOT_DIR/Builds/rclcpp/venv/lib/python"* "$DEST/Libraries/Mac"

# Copy the Python deps
cp -r -P "$ROOT_DIR/Source/rclcpp/install/lib/python"* "$DEST/Libraries/Mac"

# Copy the "share" folder
cp -r -P "$ROOT_DIR/Source/rclcpp/install/share" "$DEST/Libraries/Mac"

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
RCLCPP_ARCHIVE="$ROOT_DIR/Releases/TempoThirdParty-rclcpp-Mac-$TAG.tar.gz"
rm -rf "$RCLCPP_ARCHIVE"
tar -C "$ROOT_DIR/Outputs" -czf "$RCLCPP_ARCHIVE" rclcpp

echo "Done! Archives: $RCLCPP_ARCHIVE"
