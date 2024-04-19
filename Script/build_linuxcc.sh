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

# Check for LINUX_MULTIARCH_ROOT
if [ -z ${LINUX_MULTIARCH_ROOT+x} ]; then
  echo "LINUX_MULTIARCH_ROOT is not set";
  exit 1
fi

# Check for NINJA_EXE_PATH
if [ -z ${NINJA_EXE_PATH+x} ]; then
  echo "NINJA_EXE_PATH is not set. https://ninja-build.org/";
  exit 1
fi

echo -e "Using Linux MultiArch Root: $LINUX_MULTIARCH_ROOT\n";

PROTOC="$ROOT_DIR/Output/gRPC/Binaries/Windows/protoc.exe"
GRPC_CPP_PLUGIN="$ROOT_DIR/Output/gRPC/Binaries/Windows/grpc_cpp_plugin.exe"

# Check for Windows outputs. We need protoc.exe and gen_cpp_protobuf.exe for the gRPC build later.
if [ ! -f "${PROTOC}" ]; then
  echo "$PROTOC does not exist. Windows build must be run first.";
  exit 1
fi

if [ ! -f "${GRPC_CPP_PLUGIN}" ]; then
  echo "$GRPC_CPP_PLUGIN does not exist. Windows build must be run first.";
  exit 1
fi

# Copy the protoc and grpc cpp plugin executables before erasing the build directory.
TEMP=$(mktemp -d)
cp "$PROTOC" "$TEMP"
cp "$GRPC_CPP_PLUGIN" "$TEMP"

echo -e "All prerequisites satisfied. Starting build.\n"

NUM_JOBS="$(nproc --all)"
echo -e "Detected $NUM_JOBS processors. Will use $NUM_JOBS jobs.\n"

echo "Removing contents of Output and Build folders"
find "$ROOT_DIR/Output" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;
find "$ROOT_DIR/Build" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;

echo -e "\nBuilding re2..."
cd "$ROOT_DIR/Source/re2"
git reset --hard && git apply "$ROOT_DIR/Patch/re2.patch"
mkdir -p "$ROOT_DIR/Build/Linux/re2" && cd "$ROOT_DIR/Build/Linux/re2"
cmake -G "Ninja Multi-Config" -DCMAKE_MAKE_PROGRAM="$NINJA_EXE_PATH" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Linux" -DCMAKE_INSTALL_LIBDIR="Libraries/Linux/RE2" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/cmake" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchain/linuxcc.toolchain.cmake" \
 -DUE_THIRD_PARTY_PATH="$UE_THIRD_PARTY_PATH" \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 -DRE2_BUILD_TESTING=OFF \
 "$ROOT_DIR/Source/re2"
cmake --build . --target install --config Release -j "$NUM_JOBS"
echo -e "Successfully built re2.\n"

echo -e "Building abseil-cpp..."
cd "$ROOT_DIR/Source/abseil-cpp"
git reset --hard && git apply "$ROOT_DIR/Patch/abseil-cpp.patch"
mkdir -p "$ROOT_DIR/Build/Linux/abseil-cpp" && cd "$ROOT_DIR/Build/Linux/abseil-cpp"
cmake -G "Ninja Multi-Config" -DCMAKE_MAKE_PROGRAM="$NINJA_EXE_PATH" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Linux" -DCMAKE_INSTALL_LIBDIR="Libraries/Linux/Abseil" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/cmake" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchain/linuxcc.toolchain.cmake" \
 -DCMAKE_CXX_FLAGS=" -D ABSL_BUILD_DLL=1 " \
 -DUE_THIRD_PARTY_PATH="$UE_THIRD_PARTY_PATH" \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 -DBUILD_TESTING=OFF -DABSL_PROPAGATE_CXX_STD=ON \
  "$ROOT_DIR/Source/abseil-cpp"
cmake --build . --target install --config Release -j "$NUM_JOBS"
echo -e "Successfully built abseil-cpp.\n"

echo -e "Building protobuf..."
cd "$ROOT_DIR/Source/protobuf"
git reset --hard && git apply "$ROOT_DIR/Patch/protobuf.patch"
mkdir -p "$ROOT_DIR/Build/Linux/protobuf" && cd "$ROOT_DIR/Build/Linux/protobuf"
cmake -G "Ninja Multi-Config" -DCMAKE_MAKE_PROGRAM="$NINJA_EXE_PATH" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Linux" -DCMAKE_INSTALL_LIBDIR="Libraries/Linux/Protobuf" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/cmake" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchain/linuxcc.toolchain.cmake" \
 -DCMAKE_CXX_FLAGS=" -D PROTOBUF_USE_DLLS=1 -D LIBPROTOBUF_EXPORTS=1 " \
 -DUE_THIRD_PARTY_PATH="$UE_THIRD_PARTY_PATH" -Dprotobuf_DEBUG_POSTFIX="" \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 \
 -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_WITH_ZLIB=OFF \
 -Dprotobuf_BUILD_EXAMPLES=OFF \
 -Dprotobuf_BUILD_PROTOC_BINARIES=ON -Dprotobuf_BUILD_LIBPROTOC=ON \
 -Dprotobuf_ABSL_PROVIDER=package -Dabsl_DIR="$ROOT_DIR/Output/gRPC/Linux/Libraries/cmake" \
 "$ROOT_DIR/Source/protobuf"
cmake --build . --target install --config Release -j "$NUM_JOBS"
echo -e "Successfully built protobuf.\n"

echo -e "Building gRPC..."
cd "$ROOT_DIR/Source/gRPC"
git reset --hard && git apply "$ROOT_DIR/Patch/gRPC.patch"
mkdir -p "$ROOT_DIR/Build/Linux/gRPC" && cd "$ROOT_DIR/Build/Linux/gRPC"
cmake -G "Ninja Multi-Config" -DCMAKE_MAKE_PROGRAM="$NINJA_EXE_PATH" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DgRPC_INSTALL_BINDIR="Binaries/Linux" -DgRPC_INSTALL_LIBDIR="Libraries/Linux/gRPC" -DgRPC_INSTALL_INCLUDEDIR="Includes" -DgRPC_INSTALL_CMAKEDIR="Libraries/cmake" -DgRPC_INSTALL_SHAREDIR="Libraries/share" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchain/linuxcc.toolchain.cmake" \
 -DCMAKE_CXX_FLAGS=" -D GRPC_DLL_EXPORTS=1 -D GRPCXX_DLL_EXPORTS=1 -D GPR_DLL_EXPORTS=1 " \
 -DUE_THIRD_PARTY_PATH="$UE_THIRD_PARTY_PATH" \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 \
 -DgRPC_ABSL_PROVIDER=package -Dabsl_DIR="$ROOT_DIR/Output/gRPC/Linux/Libraries/cmake" \
 -DgRPC_RE2_PROVIDER=package -Dre2_DIR="$ROOT_DIR/Output/gRPC/Linux/Libraries/cmake" \
 -DgRPC_PROTOBUF_PROVIDER=package \
 -DProtobuf_DIR="$ROOT_DIR/Output/gRPC/Linux/Libraries/cmake" \
 -Dutf8_range_DIR="$ROOT_DIR/Output/gRPC/Linux/Libraries/cmake" \
 -DgRPC_USE_CARES=OFF -DgRPC_ZLIB_PROVIDER=package \
 -DZLIB_INCLUDE_DIR="$UE_THIRD_PARTY_PATH/zlib/1.2.13/include" \
 -DZLIB_LIBRARY_RELEASE="$UE_THIRD_PARTY_PATH/zlib/1.2.13/lib/Unix/Release/libz.a" \
 -DZLIB_LIBRARY_DEBUG="$UE_THIRD_PARTY_PATH/zlib/1.2.13/lib/Unix/Release/libz.a" \
 -DgRPC_SSL_PROVIDER=package \
 -DOPENSSL_INCLUDE_DIR="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/include/Unix" \
 -DOPENSSL_SSL_LIBRARY="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Unix/libssl.a" \
 -DOPENSSL_CRYPTO_LIBRARY="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Unix/libcrypto.a" \
 -DgRPC_BUILD_CODEGEN=ON -DgRPC_BUILD_CSHARP_EXT=OFF \
 -DgRPC_BUILD_GRPC_CPP_PLUGIN=ON -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
 -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
 -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=ON \
 -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF -D_gRPC_CPP_PLUGIN="$TEMP/grpc_cpp_plugin.exe" \
 -D_gRPC_PROTOBUF_PROTOC_EXECUTABLE="$TEMP/protoc.exe" \
 -DPACKAGE_PREFIX_DIR="$ROOT_DIR/Output/gRPC" \
 "$ROOT_DIR/Source/gRPC"
cmake --build . --target grpc_cpp_plugin --config Release -j "$NUM_JOBS"
cmake --build . --target grpc_python_plugin --config Release -j "$NUM_JOBS"
cmake --build . --target install --config Release -j "$NUM_JOBS"
echo -e "Successfully built gRPC.\n"

echo -e "Cleaning up Output directory...\n"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Linux/cmake"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Linux/share"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Linux/RE2/pkgconfig"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Linux/Abseil/pkgconfig"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Linux/Protobuf/pkgconfig"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Linux/gRPC/pkgconfig"

echo -e "Removing unused libraries...\n"
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Linux/gRPC/libgrpc++_unsecure.a" # We use libgrpc++.a
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Linux/gRPC/libgrpc_unsecure.a" # We use libgrpc.a
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Linux/Protobuf/libprotobuf-lite.a" # We use libprotobuf.a
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Linux/Protobuf/libprotoc.a" # Only needed during build of grpc code gen plugins

echo -e "Archiving outputs...\n"
ARCHIVE="$ROOT_DIR/Release/TempoThirdParty-Linux-$TAG.tar.gz"
rm -rf "$ARCHIVE"
tar -C "$ROOT_DIR/Output" -czf "$ARCHIVE" gRPC

rm -rf "$TEMP"

echo "Done! Archive: $ARCHIVE"
