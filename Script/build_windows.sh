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

echo ""

# Check for tag
TAG=$(git name-rev --tags --name-only "$(git rev-parse HEAD)")
if [ "$TAG" = "undefined" ]; then
    echo "Could not find git tag"
    exit 1
fi

echo -e "Using git tag: $TAG\n"

# Check for UNREAL_ENGINE_PATH
if [ -z ${UNREAL_ENGINE_PATH+x} ]; then
  echo "UNREAL_ENGINE_PATH is not set";
  exit 1
fi

UE_THIRD_PARTY_PATH="$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty"
if [ ! -d "${UE_THIRD_PARTY_PATH}" ]; then
  echo "ThirdParty directory does not exist: $UE_THIRD_PARTY_PATH";
  exit 1
fi

echo -e "Using Unreal Engine ThirdParty: $UE_THIRD_PARTY_PATH\n";

echo -e "All prerequisites satisfied. Starting build.\n"

NUM_JOBS="$(nproc --all)"
echo -e "Detected $NUM_JOBS processors. Will use $NUM_JOBS jobs.\n"

echo "Removing contents of Output and Build folders"
find "$ROOT_DIR/Output" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;
find "$ROOT_DIR/Build" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;

echo -e "\nBuilding re2..."
cd "$ROOT_DIR/Source/re2"
git reset --hard && git apply "$ROOT_DIR/Patch/re2.patch"
mkdir -p "$ROOT_DIR/Build/Windows/re2" && cd "$ROOT_DIR/Build/Windows/re2"
cmake -G "Visual Studio 17 2022" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Windows" -DCMAKE_INSTALL_LIBDIR="Libraries/Windows/RE2" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/cmake" \
 -DCMAKE_CXX_FLAGS=" /EHsc /MP$NUM_JOBS /std:c++20 /permissive " \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 \
 "$ROOT_DIR/Source/re2"
cmake --build . --target install --config Release -j "$NUM_JOBS" -- -m:"$NUM_JOBS"
echo -e "Successfully built re2.\n"

echo -e "Building abseil-cpp..."
cd "$ROOT_DIR/Source/abseil-cpp"
git reset --hard && git apply "$ROOT_DIR/Patch/abseil-cpp.patch"
mkdir -p "$ROOT_DIR/Build/Windows/abseil-cpp" && cd "$ROOT_DIR/Build/Windows/abseil-cpp"
cmake -G "Visual Studio 17 2022" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Windows" -DCMAKE_INSTALL_LIBDIR="Libraries/Windows/Abseil" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/cmake" \
 -DCMAKE_CXX_FLAGS=" -D ABSL_BUILD_DLL=1 /EHsc /MP$NUM_JOBS /std:c++20 /permissive " \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 \
 -DBUILD_TESTING=False -DABSL_PROPAGATE_CXX_STD=True \
 "$ROOT_DIR/Source/abseil-cpp"
cmake --build . --target INSTALL --config Release -j "$NUM_JOBS"
echo -e "Successfully built abseil-cpp.\n"

echo -e "Building protobuf..."
cd "$ROOT_DIR/Source/protobuf"
git reset --hard && git apply "$ROOT_DIR/Patch/protobuf.patch"
mkdir -p "$ROOT_DIR/Build/Windows/protobuf" && cd "$ROOT_DIR/Build/Windows/protobuf"
cmake -G "Visual Studio 17 2022" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Windows" -DCMAKE_INSTALL_LIBDIR="Libraries/Windows/Protobuf" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/cmake" \
 -DCMAKE_CXX_FLAGS=" -D PROTOBUF_USE_DLLS=1 -D LIBPROTOBUF_EXPORTS=1 /EHsc /MP$NUM_JOBS /std:c++20 /permissive " \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 \
 -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded$<$<CONFIG:Debug>:Debug>DLL" \
 -Dprotobuf_BUILD_TESTS=false -Dprotobuf_WITH_ZLIB=false \
 -Dprotobuf_BUILD_PROTOC_BINARIES=ON -Dprotobuf_BUILD_LIBPROTOC=ON \
 -Dprotobuf_DEBUG_POSTFIX="" \
 -Dprotobuf_MSVC_STATIC_RUNTIME=false \
 -Dprotobuf_ABSL_PROVIDER=package -Dabsl_DIR="$ROOT_DIR/Output/gRPC/Libraries/cmake" \
 "$ROOT_DIR/Source/protobuf"
cmake --build . --target INSTALL --config Release -j "$NUM_JOBS"
echo -e "Successfully built protobuf.\n"

echo -e "Building gRPC..."
cd "$ROOT_DIR/Source/gRPC"
git reset --hard && git apply "$ROOT_DIR/Patch/gRPC.patch"
mkdir -p "$ROOT_DIR/Build/Windows/gRPC" && cd "$ROOT_DIR/Build/Windows/gRPC"
cmake -G "Visual Studio 17 2022" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DgRPC_INSTALL_BINDIR="Binaries/Windows" -DgRPC_INSTALL_LIBDIR="Libraries/Windows/gRPC" -DgRPC_INSTALL_INCLUDEDIR="Includes" -DgRPC_INSTALL_CMAKEDIR="Libraries/cmake" -DgRPC_INSTALL_SHAREDIR="Libraries/share" \
 -DCMAKE_CXX_FLAGS=" -D GRPC_DLL_EXPORTS=1 -D GRPCXX_DLL_EXPORTS=1 -D GPR_DLL_EXPORTS=1 /EHsc /MP$NUM_JOBS /std:c++20 /permissive" \
 -DgRPC_USE_CARES=OFF -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 \
 -DgRPC_ABSL_PROVIDER=package -Dabsl_DIR="$ROOT_DIR/Output/gRPC/Libraries/cmake" \
 -DgRPC_RE2_PROVIDER=package -Dre2_DIR="$ROOT_DIR/Output/gRPC/Libraries/cmake" \
 -DgRPC_PROTOBUF_PROVIDER=package -DProtobuf_DIR="$ROOT_DIR/Output/gRPC/Libraries/cmake" \
 -Dutf8_range_DIR="$ROOT_DIR/Output/gRPC/Libraries/cmake" \
 -DgRPC_ZLIB_PROVIDER=package \
 -DZLIB_INCLUDE_DIR="$UE_THIRD_PARTY_PATH/zlib/1.2.13/include" \
 -DZLIB_LIBRARY_RELEASE="$UE_THIRD_PARTY_PATH/zlib/1.2.13/lib/Win64/Release/zlibstatic.lib" \
 -DZLIB_LIBRARY_DEBUG="$UE_THIRD_PARTY_PATH/zlib/1.2.13/lib/Win64/Debug/zlibstatic.lib" \
 -DgRPC_SSL_PROVIDER=package \
 -DOPENSSL_INCLUDE_DIR="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/include/Win64/VS2015" \
 -DLIB_EAY_LIBRARY_DEBUG="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Debug/libcrypto.lib" \
 -DLIB_EAY_LIBRARY_RELEASE="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libcrypto.lib" \
 -DLIB_EAY_DEBUG="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Debug/libcrypto.lib" \
 -DLIB_EAY_RELEASE="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libcrypto.lib" \
 -DSSL_EAY_DEBUG="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Debug/libssl.lib" \
 -DSSL_EAY_LIBRARY_DEBUG="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Debug/libssl.lib" \
 -DSSL_EAY_LIBRARY_RELEASE="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libssl.lib" \
 -DSSL_EAY_RELEASE="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Win64/VS2015/Release/libssl.lib" \
 -DgRPC_BUILD_CODEGEN=ON -DgRPC_BUILD_CSHARP_EXT=OFF \
 -DgRPC_BUILD_GRPC_CPP_PLUGIN=ON -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
 -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
 -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=ON \
 -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF \
 -DPACKAGE_PREFIX_DIR="$ROOT_DIR/Output/gRPC" \
 "$ROOT_DIR/Source/gRPC"
cmake --build . --target INSTALL --config Release -j "$NUM_JOBS"
echo -e "Successfully built gRPC.\n"

echo -e "Cleaning up Output directory...\n"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/cmake"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/share"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Windows/RE2/pkgconfig"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Windows/Abseil/pkgconfig"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Windows/Protobuf/pkgconfig"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Windows/gRPC/pkgconfig"

echo -e "Removing unused libraries...\n"
#rm -f "$ROOT_DIR/Output/gRPC/Libraries/Windows/gRPC/grpc++_unsecure.lib" # We use libgrpc++.lib
#rm -f "$ROOT_DIR/Output/gRPC/Libraries/Windows/gRPC/grpc_unsecure.lib" # We use libgrpc.lib
#rm -f "$ROOT_DIR/Output/gRPC/Libraries/Windows/gRPC/grpc_plugin_support.lib" # Only needed during build of grpc code gen plugins
#rm -f "$ROOT_DIR/Output/gRPC/Libraries/Windows/Protobuf/libprotoc.lib" # Only needed during build of grpc code gen plugins
#rm -f "$ROOT_DIR/Output/gRPC/Libraries/Windows/Protobuf/libprotobuf-lite.lib" # We use libprotobuf.lib

echo -e "Archiving outputs...\n"
ARCHIVE="$ROOT_DIR/Release/TempoThirdParty-Windows-$TAG.tar.gz"
rm -rf "$ARCHIVE"
tar -C "$ROOT_DIR/Output" -czf "$ARCHIVE" gRPC

echo "Done! Archive: $ARCHIVE"
