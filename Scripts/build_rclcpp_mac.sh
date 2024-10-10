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

# Check for tag
TAG=$(git name-rev --tags --name-only "$(git rev-parse HEAD)")
if [ "$TAG" = "undefined" ]; then
    echo "Could not find git tag"
    exit 1
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

echo -e "Using Unreal Engine ThirdParty: $UE_THIRD_PARTY_PATH\n";

echo -e "Using git tag: $TAG\n"

echo -e "All prerequisites satisfied. Starting build.\n"

echo -e "Removing stale Outputs and Builds\n"
rm -rf "$ROOT_DIR/Outputs/rclcpp"
rm -rf "$ROOT_DIR/Builds/rclcpp"
rm -rf "$ROOT_DIR/Source/rclcpp/install"
rm -rf "$ROOT_DIR/Source/rclcpp/log"

NUM_JOBS="$(sysctl -n hw.ncpu)"
echo -e "Detected $NUM_JOBS processors. Will use $NUM_JOBS jobs.\n"

echo "Applying Tempo patches..."
cd "$ROOT_DIR/Source/rclcpp/rcpputils"
git reset --hard && git apply "$ROOT_DIR/Patches/rcpputils.patch"
cd "$ROOT_DIR/Source/rclcpp/rclcpp"
git reset --hard && git apply "$ROOT_DIR/Patches/rclcpp.patch"
cd "$ROOT_DIR/Source/rclcpp/rmw"
git reset --hard && git apply "$ROOT_DIR/Patches/rmw.patch"
cd "$ROOT_DIR/Source/rclcpp/rosidl"
git reset --hard && git clean -fd && git apply "$ROOT_DIR/Patches/rosidl.patch"
cd "$ROOT_DIR/Source/rclcpp/rcutils"
git reset --hard && git apply "$ROOT_DIR/Patches/rcutils.patch"
cd "$ROOT_DIR/Source/rclcpp/python_cmake_module"
git reset --hard && git apply "$ROOT_DIR/Patches/python_cmake_module.patch"
cd "$ROOT_DIR/Source/rclcpp/pybind11_vendor"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/pybind11_vendor.patch"
cd "$ROOT_DIR/Source/rclcpp/image_common"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/image_common.patch"
cd "$ROOT_DIR/Source/rclcpp/image_transport_plugins"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/image_transport_plugins.patch"
cd "$ROOT_DIR/Source/rclcpp/Fast-DDS"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/Fast-DDS.patch"
cd "$ROOT_DIR/Source/rclcpp/Fast-CDR"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/Fast-CDR.patch"
cd "$ROOT_DIR/Source/rclcpp/rosidl_typesupport"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/rosidl_typesupport.patch"
cd "$ROOT_DIR/Source/rclcpp/pluginlib"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/pluginlib.patch"
cd "$ROOT_DIR/Source/rclcpp/cyclonedds"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/cyclonedds.patch"
cd "$ROOT_DIR/Source/rclcpp/class_loader"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/class_loader.patch"
cd "$ROOT_DIR/Source/rclcpp/boost/libs/python"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/boost-python.patch"
cd "$ROOT_DIR/Source/rclcpp/boost/libs/exception"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/boost-exception.patch"
cd "$ROOT_DIR/Source/rclcpp/geometry2"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/geometry2.patch"
cd "$ROOT_DIR/Source/rclcpp/theora"
git reset --hard && git clean -df && git apply "$ROOT_DIR/Patches/theora.patch"
cd "$ROOT_DIR/Source/rclcpp/orocos_kdl_vendor"
git reset --hard && git clean -df && git apply "$ROOT_DIR/Patches/orocos_kdl_vendor.patch"
cd "$ROOT_DIR/Source/rclcpp/libstatistics_collector"
git reset --hard && git clean -df && git apply "$ROOT_DIR/Patches/libstatistics_collector.patch"
cd "$ROOT_DIR/Source/rclcpp/common_interfaces"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/common_interfaces.patch"
cd "$ROOT_DIR/Source/rclcpp/mimick_vendor"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/mimick_vendor.patch"
cd "$ROOT_DIR/Source/rclcpp/rcl_interfaces"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/rcl_interfaces.patch"
cd "$ROOT_DIR/Source/rclcpp/rmw_cyclonedds"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/rmw_cyclonedds.patch"
cd "$ROOT_DIR/Source/rclcpp/rmw_dds_common"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/rmw_dds_common.patch"
cd "$ROOT_DIR/Source/rclcpp/rmw_fastrtps"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/rmw_fastrtps.patch"
cd "$ROOT_DIR/Source/rclcpp/rosidl_python"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/rosidl_python.patch"
cd "$ROOT_DIR/Source/rclcpp/unique_identifier_msgs"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/unique_identifier_msgs.patch"
cd "$ROOT_DIR/Source/rclcpp/vision_opencv"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/vision_opencv.patch"
cd "$ROOT_DIR/Source/rclcpp/vorbis"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/vorbis.patch"

echo -e "Copying asio"
mkdir -p "$ROOT_DIR/Source/rclcpp/install/include/asio"
cp -r "$ROOT_DIR/Source/rclcpp/asio/asio/include/asio" "$ROOT_DIR/Source/rclcpp/install/include/asio/asio"
cp -r "$ROOT_DIR/Source/rclcpp/asio/asio/include/asio.hpp" "$ROOT_DIR/Source/rclcpp/install/include/asio"

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
./autogen.sh
./configure --prefix="$ROOT_DIR/Source/rclcpp/install" --with-ogg="$ROOT_DIR/Source/rclcpp/install" --disable-examples
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

echo -e "Creating Python virtual environment for colcon build.\n"
cd "$UNREAL_ENGINE_PATH"
./Engine/Binaries/ThirdParty/Python3/Mac/bin/python3 -m venv "$ROOT_DIR/Builds/rclcpp/venv"
source "$ROOT_DIR/Builds/rclcpp/venv/bin/activate"
pip install colcon-common-extensions
pip install empy==3.3.4
pip install lark==1.1.1
pip install numpy
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

# To inspect compiler/linker commands
# export VERBOSE=1
# --cmake-clean-cache \
# --event-handlers console_direct+ \
export PKG_CONFIG_PATH="$ROOT_DIR/Source/rclcpp/pkgconfig:$PKG_CONFIG_PATH"
colcon build --packages-skip-by-dep python_qt_binding --packages-skip Boost OpenCV libogg vorbis \
 --build-base "$ROOT_DIR/Builds/rclcpp/Mac" \
 --merge-install \
 --catkin-skip-building-tests \
 --parallel-workers "$NUM_JOBS" \
 --event-handlers console_direct+ \
 --cmake-args \
 " -DCMAKE_CXX_STANDARD=20" \
 " -DAsio_INCLUDE_DIR=$ROOT_DIR/Source/rclcpp/install/include/asio" \
 " -DTHIRDPARTY_Asio=FORCE" \
 " -DBUILD_TESTS=OFF" \
 " -DBUILD_TESTING=OFF" \
 " -DZLIB_LIBRARY='$UE_THIRD_PARTY_PATH/zlib/1.2.13/lib/Mac/Release/libz.a'" \
 " -DZLIB_LIBRARIES='$UE_THIRD_PARTY_PATH/zlib/1.2.13/lib/Mac/Release/libz.a'" \
 " -DZLIB_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/zlib/1.2.13/include'" \
 " -DZLIB_USE_STATIC_LIBS=ON" \
 " -DZLIB_FOUND=ON" \
 " -DPNG_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.5.27'" \
 " -DPNG_PNG_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.5.27'" \
 " -DPNG_LIBRARIES='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.5.27/lib/Mac/libpng.a'" \
 " -DPNG_LIBRARY='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.5.27/lib/Mac/libpng.a'" \
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
 " -DPython3_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include'" \
 " -DPythonExtra_INCLUDE_DIRS='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include'" \
 " -DPythonExtra_LIBRARIES='$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/libpython3.11.dylib'" \
 " -DPYTHON_LIBRARY='$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Mac/libpython3.11.dylib'" \
 " -DPYTHON_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Linux/include'" \
 " -DCMAKE_CXX_FLAGS=-isystem '$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include' -mmacosx-version-min=10.15 -Wno-unused-command-line-argument -Wno-error=unused-command-line-argument" \
 " -DCMAKE_C_FLAGS=-isystem '$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Mac/include' -mmacosx-version-min=10.15 -Wno-unused-command-line-argument -Wno-error=unused-command-line-argument" \
 " --no-warn-unused-cli"

DEST="$ROOT_DIR/Outputs/rclcpp"

# Copy the binaries
cp -r -P "$ROOT_DIR/Source/rclcpp/install/bin"/* "$DEST/Binaries/Mac"

# Copy the libraries
find "$ROOT_DIR/Source/rclcpp/install" -name "*.dylib" -exec cp -P {} "$DEST/Libraries/Mac" \;

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
