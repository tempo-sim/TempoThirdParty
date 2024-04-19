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

UNREAL_ENGINE_PATH="${UNREAL_ENGINE_PATH//\\//}"

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

LINUX_ARCH_NAME="x86_64-unknown-linux-gnu"
LINUX_MULTIARCH_ROOT="${LINUX_MULTIARCH_ROOT//\\//}"

# Check for NINJA_EXE_PATH
if [ -z ${NINJA_EXE_PATH+x} ]; then
  echo "NINJA_EXE_PATH is not set. https://ninja-build.org/";
  exit 1
fi

echo -e "Using Linux MultiArch Root: $LINUX_MULTIARCH_ROOT\n";

PROTOC="$ROOT_DIR/Outputs/gRPC/Binaries/Windows/protoc.exe"
GRPC_CPP_PLUGIN="$ROOT_DIR/Outputs/gRPC/Binaries/Windows/grpc_cpp_plugin.exe"

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

echo -e "Removing stale Outputs and Builds\n"
rm -rf "$ROOT_DIR/Outputs/gRPC"
rm -rf "$ROOT_DIR/Builds/gRPC"

echo "Applying Tempo patches..."
cd "$ROOT_DIR/Source/gRPC"
git reset --hard && git apply "$ROOT_DIR/Patches/gRPC.patch"
cd "$ROOT_DIR/Source/gRPC/third_party/re2"
git reset --hard && git apply "$ROOT_DIR/Patches/re2.patch"
cd "$ROOT_DIR/Source/gRPC/third_party/abseil-cpp"
git reset --hard && git apply "$ROOT_DIR/Patches/abseil-cpp.patch"
cd "$ROOT_DIR/Source/gRPC/third_party/protobuf"
git reset --hard && git apply "$ROOT_DIR/Patches/protobuf.patch"
echo -e "Successfully applied patches\n"

echo -e "Building gRPC..."
mkdir -p "$ROOT_DIR/Builds/gRPC/Linux" && cd "$ROOT_DIR/Builds/gRPC/Linux"

# Bash doesn't support inline comments in a multi-line command, but the following command is broken
# into these sections for clarity:
# - Install directory stuff
# - Compiler & linker stuff
# - RE2 stuff
# - Abseil stuff
# - Protobuf stuff
# - gRPC Stuff
cmake -G "Ninja Multi-Config" -DCMAKE_MAKE_PROGRAM="$NINJA_EXE_PATH" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Outputs/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Linux" -DCMAKE_INSTALL_LIBDIR="Libraries/Linux" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/Linux/cmake" \
 -DgRPC_INSTALL_BINDIR="Binaries/Linux" -DgRPC_INSTALL_LIBDIR="Libraries/Linux" -DgRPC_INSTALL_INCLUDEDIR="Includes" -DgRPC_INSTALL_CMAKEDIR="Libraries/Linux/cmake" -DgRPC_INSTALL_SHAREDIR="Libraries/Linux/share" \
 \
 -DUE_THIRD_PARTY_PATH="$UE_THIRD_PARTY_PATH" \
 -DLINUX_MULTIARCH_ROOT="$LINUX_MULTIARCH_ROOT" -DLINUX_ARCH_NAME="$LINUX_ARCH_NAME" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchains/linuxcc.toolchain.cmake" \
 -DCMAKE_CXX_FLAGS=" -D ABSL_BUILD_DLL=1 -D PROTOBUF_USE_DLLS=1 -D LIBPROTOBUF_EXPORTS=1 -D LIBPROTOC_EXPORTS=1 \
                     -D GRPC_DLL_EXPORTS=1 -D GRPCXX_DLL_EXPORTS=1 -D GPR_DLL_EXPORTS=1" \
 \
 -DRE2_BUILD_TESTING=OFF \
 \
 -DBUILD_TESTING=OFF -DABSL_PROPAGATE_CXX_STD=ON \
 \
 -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_WITH_ZLIB=OFF -Dprotobuf_BUILD_EXAMPLES=OFF \
 -Dprotobuf_BUILD_PROTOC_BINARIES=ON -Dprotobuf_BUILD_LIBPROTOC=ON -Dprotobuf_DISABLE_RTTI=ON \
 \
 -DgRPC_USE_CARES=OFF -DgRPC_USE_PROTO_LITE=OFF \
 -DgRPC_ZLIB_PROVIDER=package \
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
 "$ROOT_DIR/Source/gRPC"
cmake --build . --target grpc_cpp_plugin --config Release -j "$NUM_JOBS"
cmake --build . --target grpc_python_plugin --config Release -j "$NUM_JOBS"
cmake --build . --target install --config Release -j "$NUM_JOBS"
echo -e "Successfully built gRPC.\n"

echo -e "Cleaning up output directory...\n"
rm -rf "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/cmake"
rm -rf "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/share"
rm -rf "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/pkgconfig"

echo -e "Removing unused libraries...\n"
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/libgrpc++_unsecure.a" # We use libgrpc++.a
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/libgrpc_unsecure.a" # We use libgrpc.a
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/libprotobuf-lite.a" # We use libprotobuf.a
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/libgrpc_plugin_support.a" # Only needed during build of grpc code gen plugins
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/libprotoc.a" # Only needed during build of grpc code gen plugins
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/libutf8_range_lib.a" # Redundant with libutf8_range.a

# We want to re-export all symbols from these libraries through one Unreal dll.
# libgrpc_authorization_provider.a, libupb_json_lib.a, and libupb_textformat_lib.a for some reason have symbols in common with libgrpc.a. So we don't want to force them to load.
find "$ROOT_DIR/Outputs/gRPC/Libraries/Linux" -type f -name "*.a" ! -name "libgrpc_authorization_provider.a" ! \
  -name "libupb_json_lib.a" ! -name "libupb_textformat_lib.a" -exec basename {} \; > "$ROOT_DIR/Outputs/gRPC/Libraries/Linux/exports.def"

echo -e "Archiving outputs...\n"
ARCHIVE="$ROOT_DIR/Releases/TempoThirdParty-gRPC-Linux-$TAG.tar.gz"
rm -rf "$ARCHIVE"
tar -C "$ROOT_DIR/Outputs" -czf "$ARCHIVE" gRPC

rm -rf "$TEMP"

echo "Done! Archive: $ARCHIVE"
