#!/usr/bin/env bash

set -e

if [[ ! "$OSTYPE" = "linux-gnu"* ]]; then
      echo "This script can only be run on Linux"
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

if [ ! -d "$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Linux/lib/python3.11" ]; then
  echo "Unreal's python3 is missing or unexpected version (expected 3.11)";
  exit 1
fi

UE_THIRD_PARTY_PATH="$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty"
if [ ! -d "${UE_THIRD_PARTY_PATH}" ]; then
  echo "ThirdParty directory does not exist: $UE_THIRD_PARTY_PATH";
  exit 1
fi

echo -e "Using Unreal Engine ThirdParty: $UE_THIRD_PARTY_PATH\n";

LINUX_MULTIARCH_ROOT="$UNREAL_ENGINE_PATH/Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/v22_clang-16.0.6-centos7"
LINUX_ARCH_NAME="x86_64-unknown-linux-gnu"
export UE_THIRD_PARTY_PATH="$UE_THIRD_PARTY_PATH"
export LINUX_MULTIARCH_ROOT="$LINUX_MULTIARCH_ROOT"
export LINUX_ARCH_NAME="$LINUX_ARCH_NAME"

echo -e "Using git tag: $TAG\n"

echo -e "All prerequisites satisfied. Starting build.\n"

echo -e "Removing stale Outputs and Builds\n"
rm -rf "$ROOT_DIR/Outputs/rclcpp"
rm -rf "$ROOT_DIR/Builds/rclcpp"
rm -rf "$ROOT_DIR/Source/rclcpp/install"
rm -rf "$ROOT_DIR/Source/rclcpp/log"

NUM_JOBS="$(nproc --all)"
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

echo -e "Building boost"
cd "$ROOT_DIR/Source/rclcpp/boost"
./bootstrap.sh --prefix="$ROOT_DIR/Source/rclcpp/install"
./b2 install toolset=clang-unreal --with-python --user-config="$ROOT_DIR/Source/rclcpp/boost_user_configs/boost-user-config-linux.jam" -d0 cxxflags="-std=c++11"

echo -e "Building ogg"
cd "$ROOT_DIR/Source/rclcpp/ogg"
./autogen.sh
./configure --prefix="$ROOT_DIR/Source/rclcpp/install"
make install

echo -e "Building theora"
cd "$ROOT_DIR/Source/rclcpp/theora"
./autogen.sh
./configure --prefix="$ROOT_DIR/Source/rclcpp/install" --with-ogg="$ROOT_DIR/Source/rclcpp/install" --disable-examples
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
 -DPYTHON_EXECUTABLE="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Linux/bin/python3" \
 -DBUILD_opencv_python2=OFF \
 -DPYTHON3_EXECUTABLE="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Linux/bin/python3" \
 -DPYTHON3_INCLUDE_DIR="$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Linux/include" \
 -DPYTHON3_PACKAGES_PATH="$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Linux/lib" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchains/linux.toolchain.cmake" \
 "$ROOT_DIR/Source/rclcpp/opencv"
cmake --build . -t install -j "$NUM_JOBS"

echo -e "Creating Python virtual environment for colcon build.\n"
cd "$UNREAL_ENGINE_PATH"
./Engine/Binaries/ThirdParty/Python3/Linux/bin/python3 -m venv "$ROOT_DIR/Builds/rclcpp/venv"
source "$ROOT_DIR/Builds/rclcpp/venv/bin/activate"
pip install colcon-common-extensions
pip install empy==3.3.4
pip install lark==1.1.1
pip install numpy
# 'pip install netifaces' builds from source, but Unreal's python config has a bunch of hard-coded
# paths to some engineer's machine, which makes that difficult. So we use this pre-compiled one for
# Python3.11 instead.
pip install "$ROOT_DIR/Source/rclcpp/netifaces/netifaces-0.11.0-cp311-cp311-linux_x86_64.whl"

echo "Building rclcpp..."
mkdir -p "$ROOT_DIR/Builds/rclcpp/Linux"
cd "$ROOT_DIR/Source/rclcpp"

mkdir -p "$ROOT_DIR/Outputs/rclcpp/Binaries/Linux"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Libraries/Linux"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Includes"

# To inspect compiler/linker commands
# export VERBOSE=1
# --event-handlers console_direct+ \
export PKG_CONFIG_PATH="$ROOT_DIR/Source/rclcpp/pkgconfig:$PKG_CONFIG_PATH"
colcon build --packages-skip-by-dep python_qt_binding --packages-skip Boost OpenCV libogg vorbis \
 --build-base "$ROOT_DIR/Builds/rclcpp/Linux" \
 --merge-install \
 --catkin-skip-building-tests \
 --cmake-clean-cache \
 --parallel-workers "$NUM_JOBS" \
 --cmake-args \
 " -DAsio_INCLUDE_DIR=$ROOT_DIR/Source/rclcpp/install/include/asio" \
 " -DTHIRDPARTY_Asio=FORCE" \
 " -DPNG_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.5.2'" \
 " -DPNG_LIBRARIES='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.5.2/lib/Unix/$LINUX_ARCH_NAME/libpng.a'" \
 " -DPNG_FOUND=ON" \
 " -DPNG_PNG_INCLUDE_DIR='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.5.2'" \
 " -DPNG_LIBRARY='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.5.2/lib/Unix/$LINUX_ARCH_NAME/libpng.a'" \
 " -DZLIB_LIBRARY='$UE_THIRD_PARTY_PATH/zlib/1.3/lib/Unix/$LINUX_ARCH_NAME/Release/libz.a'" \
 " -DZLIB_LIBRARIES='$UE_THIRD_PARTY_PATH/zlib/1.3/lib/Unix/$LINUX_ARCH_NAME/Release/libz.a'" \
 " -DZLIB_INCLUDE_DIR='$UE_THIRD_PARTY_PATH/zlib/1.3/include'" \
 " -DZLIB_FOUND=ON" \
 " -DZLIB_USE_STATIC_LIBS=ON" \
 " -DJPEG_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/libJPG'" \
 " -DOpenCV_DIR='$ROOT_DIR/Builds/rclcpp/opencv'" \
 " -DBOOST_ROOT='$ROOT_DIR/Source/rclcpp/install'" \
 " -DBoost_NO_SYSTEM_PATHS=ON" \
 " -Dtinyxml2_SHARED_LIBS=ON" \
 " -DTHREADS_PREFER_PTHREAD_FLAG=ON" \
 " -DSM_RUN_RESULT=0" \
 " -DSM_RUN_RESULT__TRYRUN_OUTPUT=''" \
 " -DCMAKE_MODULE_PATH=$ROOT_DIR/Source/rclcpp/cmake/Modules/Linux" \
 " -DCMAKE_TOOLCHAIN_FILE=$ROOT_DIR/Toolchains/linux.toolchain.cmake" \
 " -DCMAKE_POLICY_DEFAULT_CMP0148=OLD" \
 " -DCMAKE_POLICY_DEFAULT_CMP0074=OLD" \
 " -DCMAKE_POLICY_DEFAULT_CMP0144=NEW" \
 " -DCMAKE_INSTALL_RPATH='\$ORIGIN:\$ORIGIN/../../../../../../../../Engine/Binaries/ThirdParty/Python3/Linux/lib:\$ORIGIN/../../../../../../../../../Engine/Binaries/ThirdParty/Python3/Linux/lib'" \
 " -DTRACETOOLS_DISABLED=ON" \
 " -DBoost_NO_BOOST_CMAKE=ON" \
 " -DFORCE_BUILD_VENDOR_PKG=ON" \
 " -DPython3_EXECUTABLE='$ROOT_DIR/Builds/rclcpp/venv/bin/python3'" \
 " -DPython3_LIBRARY='$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Linux/lib/libpython3.11.so'" \
 " -DPython3_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Linux/include'" \
 " -DPYTHON_LIBRARY='$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Linux/lib/libpython3.11.so'" \
 " -DPYTHON_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Linux/include'" \
 " -DCMAKE_CXX_FLAGS=-isystem '$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Linux/include' -stdlib=libc++ -fuse-ld=lld" \
 " -DCMAKE_C_FLAGS=-isystem '$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Linux/include'" \
 " --no-warn-unused-cli"

DEST="$ROOT_DIR/Outputs/rclcpp"

# Copy the binaries
cp -r -P "$ROOT_DIR/Source/rclcpp/install/bin"/* "$DEST/Binaries/Linux"

# Copy the libraries
find "$ROOT_DIR/Source/rclcpp/install" -name "*.so*" -exec cp -P {} "$DEST/Libraries/Linux" \;

# Copy the Python deps from the virtual environment
cp -r -P "$ROOT_DIR/Builds/rclcpp/venv/lib/python"* "$DEST/Libraries/Linux"

# Copy the Python deps
cp -r -P "$ROOT_DIR/Source/rclcpp/install/lib/python"* "$DEST/Libraries/Linux"

# Copy the "share" folder
cp -r -P "$ROOT_DIR/Source/rclcpp/install/share" "$DEST/Libraries/Linux"

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
RCLCPP_ARCHIVE="$ROOT_DIR/Releases/TempoThirdParty-rclcpp-Linux-$TAG.tar.gz"
rm -rf "$RCLCPP_ARCHIVE"
tar -C "$ROOT_DIR/Outputs" -czf "$RCLCPP_ARCHIVE" rclcpp

echo "Done! Archives: $RCLCPP_ARCHIVE"
