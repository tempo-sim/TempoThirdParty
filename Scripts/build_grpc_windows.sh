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

# Check for Python3
if ! which python; then
    echo "Couldn't find python"
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

NUM_JOBS=$(nproc --all)
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
mkdir -p "$ROOT_DIR/Builds/gRPC/Windows" && cd "$ROOT_DIR/Builds/gRPC/Windows"

# Bash doesn't support inline comments in a multi-line command, but the following command is broken
# into these sections for clarity:
# - Install directory stuff
# - Compiler & linker stuff
# - RE2 stuff
# - Abseil stuff
# - Protobuf stuff
# - gRPC Stuff
cmake -G "Visual Studio 17 2022" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Outputs/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Windows" -DCMAKE_INSTALL_LIBDIR="Libraries/Windows" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/Windows/cmake" \
 -DgRPC_INSTALL_BINDIR="Binaries/Windows" -DgRPC_INSTALL_LIBDIR="Libraries/Windows" -DgRPC_INSTALL_INCLUDEDIR="Includes" -DgRPC_INSTALL_CMAKEDIR="Libraries/Windows/cmake" -DgRPC_INSTALL_SHAREDIR="Libraries/Windows/share" \
 \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded$<$<CONFIG:Debug>:Debug>DLL" \
 -DCMAKE_CXX_FLAGS=" /EHsc /MP$NUM_JOBS /std:c++20 /permissive \
 -D ABSL_BUILD_DLL=1 -D PROTOBUF_USE_DLLS=1 -D LIBPROTOBUF_EXPORTS=1 -D LIBPROTOC_EXPORTS=1 \
 -D GRPC_DLL_EXPORTS=1 -D GRPCXX_DLL_EXPORTS=1 -D GPR_DLL_EXPORTS=1" \
 \
 -DRE2_BUILD_TESTING=OFF \
 \
 -DBUILD_TESTING=OFF -DABSL_PROPAGATE_CXX_STD=ON \
 \
 -Dprotobuf_MSVC_STATIC_RUNTIME=OFF -Dprotobuf_DEBUG_POSTFIX="" \
 -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_WITH_ZLIB=OFF -Dprotobuf_BUILD_EXAMPLES=OFF \
 -Dprotobuf_BUILD_PROTOC_BINARIES=ON -Dprotobuf_BUILD_LIBPROTOC=ON -Dprotobuf_DISABLE_RTTI=ON \
 \
 -DgRPC_USE_CARES=OFF -DgRPC_USE_PROTO_LITE=OFF \
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
 "$ROOT_DIR/Source/gRPC"
cmake --build . --target INSTALL --config Release -j "$NUM_JOBS"
echo -e "Successfully built gRPC.\n"

echo -e "Cleaning up output directory...\n"
rm -rf "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/cmake"
rm -rf "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/share"
rm -rf "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/pkgconfig"

echo -e "Removing unused libraries...\n"
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/grpc++_unsecure.lib" # We use grpc++.lib
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/grpc_unsecure.lib" # We use grpc.lib
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/libprotobuf-lite.lib" # We use libprotobuf.lib
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/grpc_plugin_support.lib" # Only needed during build of grpc code gen plugins
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/libprotoc.lib" # Only needed during build of grpc code gen plugins
rm -f "$ROOT_DIR/Outputs/gRPC/Libraries/Windows/utf8_range_lib.lib" # Redundant with utf8_range.lib

# We want to re-export all symbols from these libraries through one Unreal dll.
# On Mac and Linux the linkers have options to force loading and re-exporting of all symbols.
# MSVC LINK has /WHOLEARCHIVE which supposedly "can" do exactly that but in practice does not seem to.
# However LINK does support the /DEF option which allows you to supply a .def file specifying all the dll's exports.
# So, on Windows only, we generate a full list of symbols to give to the linker in a .def file.
echo -e "Extracting symbols from all libraries...\n"
eval "$ROOT_DIR/Utils/extract_symbols.py --tools dumpbin --mangling itanium \
 --namespaces grpc protobuf upb absl re2 google envoy census telemetry cares xds bloaty benchmark utf8_range \
 --libdir $ROOT_DIR/Outputs/gRPC/Libraries/Windows -o $ROOT_DIR/Outputs/gRPC/Libraries/Windows/exports.def"

echo -e "Archiving outputs...\n"
ARCHIVE="$ROOT_DIR/Releases/TempoThirdParty-gRPC-Windows-$TAG.tar.gz"
rm -rf "$ARCHIVE"
tar -C "$ROOT_DIR/Outputs" -czf "$ARCHIVE" gRPC

echo "Done! Archive: $ARCHIVE"
