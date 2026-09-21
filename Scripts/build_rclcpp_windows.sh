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

if [ ! -f "$UNREAL_ENGINE_PATH/Engine/Binaries/ThirdParty/Python3/Win64/python311.dll" ]; then
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

BUILD_DIR="/c/rclbld"

echo -e "Removing stale Outputs and Builds\n"
rm -rf "$ROOT_DIR/Outputs/rclcpp"
rm -rf "$BUILD_DIR"
rm -rf "$ROOT_DIR/Source/rclcpp/install"
rm -rf "$ROOT_DIR/Source/rclcpp/log"

mkdir -p $BUILD_DIR

NUM_JOBS=$(nproc --all)
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
cd "$ROOT_DIR/Source/rclcpp/rosidl_typesupport_fastrtps"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/rosidl_typesupport_fastrtps.patch"
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
cd "$ROOT_DIR/Source/rclcpp/yaml_cpp_vendor"
git reset --hard && git clean -f && git apply "$ROOT_DIR/Patches/yaml_cpp_vendor.patch"

echo -e "Copying asio"
mkdir -p "$ROOT_DIR/Source/rclcpp/install/include/asio"
cp -r "$ROOT_DIR/Source/rclcpp/asio/asio/include/asio" "$ROOT_DIR/Source/rclcpp/install/include/asio/asio"
cp -r "$ROOT_DIR/Source/rclcpp/asio/asio/include/asio.hpp" "$ROOT_DIR/Source/rclcpp/install/include/asio"

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

cp -r "$UE_THIRD_PARTY_PATH/Eigen" "$BUILD_DIR/eigen-cp"

echo -e "Creating Python virtual environment for colcon build.\n"
cd "$UNREAL_ENGINE_PATH"
./Engine/Binaries/ThirdParty/Python3/Win64/python.exe -m venv "$BUILD_DIR/venv"
source "$BUILD_DIR/venv/Scripts/activate"
pip install colcon-common-extensions
pip install empy==3.3.4
pip install lark==1.1.1
pip install numpy
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
# cmake.exe is a native Windows program, so every path we hand it has to be a Windows path. MSYS only
# rewrites arguments it recognizes as paths, and it does not rewrite the quoted "-DVAR='...'" strings
# we pass through colcon's --cmake-args, so anything derived from $ROOT_DIR must be converted here.
# Getting this wrong fails silently: CMake stores the unusable /c/... value and then either reports
# the package as NOTFOUND or ignores the setting entirely.
NATIVE_ROOT_DIR=$(cygpath -m "$ROOT_DIR")
NATIVE_EIGEN_PATH=$(cygpath -w "$BUILD_DIR/eigen-cp")
NATIVE_PYTHON_PATH=$(cygpath -w "$BUILD_DIR/venv/Scripts/python.exe")
export CMAKE_PREFIX_PATH="$NATIVE_ROOT_DIR/Source/rclcpp/cmake"
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
 " -DBUILD_SHARED_LIBS=ON" \
 " -DBUILD_TESTS=OFF" \
 " -DBUILD_TESTING=OFF" \
 " -DEIGEN3_INCLUDE_DIR='$NATIVE_EIGEN_PATH'" \
 " -DCMAKE_C_COMPILER_WORKS=ON" \
 " -DCMAKE_CXX_COMPILER_WORKS=ON" \
 " -DZLIB_LIBRARY='$UE_THIRD_PARTY_PATH/zlib/1.3/lib/Win64/Release/zlibstatic.lib'" \
 " -DZLIB_LIBRARIES='$UE_THIRD_PARTY_PATH/zlib/1.3/lib/Win64/Release/zlibstatic.lib'" \
 " -DZLIB_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/zlib/1.3/include'" \
 " -DZLIB_USE_STATIC_LIBS=ON" \
 " -DZLIB_FOUND=ON" \
 " -DPNG_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44'" \
 " -DPNG_PNG_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44'" \
 " -DPNG_LIBRARIES='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44/lib/Win64/x64/Release/libpng.lib'" \
 " -DPNG_LIBRARY='$UE_THIRD_PARTY_PATH/libPNG/libPNG-1.6.44/lib/Win64/x64/Release/libpng.lib'" \
 " -DPNG_FOUND=ON" \
 " -DJPEG_INCLUDE_DIRS='$UE_THIRD_PARTY_PATH/libJPG'" \
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
 " -DOPENSSL_ROOT_DIR='$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t'" \
 " -DOPENSSL_INCLUDE_DIR='$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/include/Win64/VS2015'" \
 " -DOPENSSL_CRYPTO_LIBRARY='$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libcrypto.lib'" \
 " -DOPENSSL_SSL_LIBRARY='$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libssl.lib'" \
 " -DCMAKE_POLICY_DEFAULT_CMP0144=NEW" \
 " -DTRACETOOLS_DISABLED=ON" \
 " -DFORCE_BUILD_VENDOR_PKG=ON" \
 " -DPython3_LIBRARY='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/libs/python311.lib'" \
 " -DPython3_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/include'" \
 " -DPYTHON_EXECUTABLE='$NATIVE_PYTHON_PATH'" \
 " -DPYTHON_LIBRARY='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/libs/python311.lib'" \
 " -DPYTHON_INCLUDE_DIR='$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty/Python3/Win64/include'" \
 " --no-warn-unused-cli"

DEST="$ROOT_DIR/Outputs/rclcpp"

# Copy the binaries
cp -r -P "$ROOT_DIR/Source/rclcpp/install/lib/theora.dll" "$DEST/Binaries/Windows/libtheora.dll"
cp -r -P "$ROOT_DIR/Source/rclcpp/install/lib/tf2_eigen_kdl.dll" "$DEST/Binaries/Windows"
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
