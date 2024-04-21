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

UE_THIRD_PARTY_PATH=$UNREAL_ENGINE_PATH/Engine/Source/ThirdParty
if [ ! -d "${UE_THIRD_PARTY_PATH}" ]; then
  echo "ThirdParty directory does not exist: $UE_THIRD_PARTY_PATH";
  exit 1
fi

echo -e "Using Unreal Engine ThirdParty: $UE_THIRD_PARTY_PATH\n";

echo -e "All prerequisites satisfied. Starting build.\n"

NUM_JOBS="$(sysctl -n hw.ncpu)"
echo -e "Detected $NUM_JOBS processors. Will use $NUM_JOBS jobs.\n"

echo -e "Removing contents of Output and Build folders\n"
find "$ROOT_DIR/Output" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;
find "$ROOT_DIR/Build" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;

echo "Applying Tempo patches..."
cd "$ROOT_DIR/Source/gRPC"
git reset --hard && git apply "$ROOT_DIR/Patch/gRPC.patch"
cd "$ROOT_DIR/Source/gRPC/third_party/re2"
git reset --hard && git apply "$ROOT_DIR/Patch/re2.patch"
cd "$ROOT_DIR/Source/gRPC/third_party/abseil-cpp"
git reset --hard && git apply "$ROOT_DIR/Patch/abseil-cpp.patch"
cd "$ROOT_DIR/Source/gRPC/third_party/protobuf"
git reset --hard && git apply "$ROOT_DIR/Patch/protobuf.patch"
echo -e "Successfully applied patches\n"

echo "Building gRPC..."
mkdir -p "$ROOT_DIR/Build/Mac/gRPC" && cd "$ROOT_DIR/Build/Mac/gRPC"
cmake -G "Unix Makefiles" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DCMAKE_INSTALL_BINDIR="Binaries/Mac" -DCMAKE_INSTALL_LIBDIR="Libraries/Mac" -DCMAKE_INSTALL_INCLUDEDIR="Includes" -DCMAKE_INSTALL_CMAKEDIR="Libraries/Mac/cmake" \
 -DgRPC_INSTALL_BINDIR="Binaries/Mac" -DgRPC_INSTALL_LIBDIR="Libraries/Mac" -DgRPC_INSTALL_INCLUDEDIR="Includes" -DgRPC_INSTALL_CMAKEDIR="Libraries/Mac/cmake" -DgRPC_INSTALL_SHAREDIR="Libraries/Mac/share" \
 -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
 -DCMAKE_MACOSX_BUNDLE=OFF -DCMAKE_SHARED_LINKER_FLAGS=" -ld_classic" \
 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_STANDARD=20 \
 -DCMAKE_CXX_FLAGS=" -fno-rtti -fexceptions -DPLATFORM_EXCEPTIONS_DISABLED=0 -fmessage-length=0 -fpascal-strings -fasm-blocks -ffp-contract=off -fvisibility-ms-compat -fvisibility-inlines-hidden -D GRPC_DLL_EXPORTS=1 -D GRPCXX_DLL_EXPORTS=1 -D GPR_DLL_EXPORTS=1 -D PROTOBUF_USE_DLLS=1 -D LIBPROTOBUF_EXPORTS=1 -D LIBPROTOC_EXPORTS=1 -D ABSL_BUILD_DLL=1 " \
 -DRE2_BUILD_TESTING=OFF \
 -DBUILD_TESTING=OFF -DABSL_PROPAGATE_CXX_STD=ON \
 -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_WITH_ZLIB=OFF -Dprotobuf_BUILD_EXAMPLES=OFF  \
 -Dprotobuf_BUILD_PROTOC_BINARIES=ON -Dprotobuf_BUILD_LIBPROTOC=ON -Dprotobuf_DISABLE_RTTI=ON \
 -DgRPC_USE_CARES=OFF -DgRPC_USE_PROTO_LITE=ON \
 -DgRPC_ZLIB_PROVIDER=package \
 -DZLIB_INCLUDE_DIR="$UE_THIRD_PARTY_PATH/zlib/1.2.13/include" \
 -DZLIB_LIBRARY_RELEASE="$UE_THIRD_PARTY_PATH/zlib/1.2.13/lib/Mac/Release/libz.a" \
 -DZLIB_LIBRARY_DEBUG="$UE_THIRD_PARTY_PATH/zlib/1.2.13/lib/Mac/Release/libz.a" \
 -DgRPC_SSL_PROVIDER=package \
 -DOPENSSL_INCLUDE_DIR="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/include/Mac" \
 -DOPENSSL_SSL_LIBRARY="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Mac/libssl.a" \
 -DOPENSSL_CRYPTO_LIBRARY="$UE_THIRD_PARTY_PATH/OpenSSL/1.1.1t/lib/Mac/libcrypto.a" \
 -DgRPC_BUILD_CODEGEN=ON -DgRPC_BUILD_CSHARP_EXT=OFF \
 -DgRPC_BUILD_GRPC_CPP_PLUGIN=ON -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
 -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
 -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=ON \
 -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF -D_gRPC_CPP_PLUGIN="$ROOT_DIR/Build/Mac/gRPC/grpc_cpp_plugin" \
 -D_gRPC_PROTOBUF_PROTOC_EXECUTABLE="$ROOT_DIR/Build/Mac/gRPC/protoc" \
 "$ROOT_DIR/Source/gRPC"
cmake --build . --target grpc_cpp_plugin --config Release -j "$NUM_JOBS"
cmake --build . --target grpc_python_plugin --config Release -j "$NUM_JOBS"
cmake --build . --target install --config Release -j "$NUM_JOBS"
echo -e "Successfully built gRPC.\n"

echo -e "Cleaning up Output directory...\n"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Mac/cmake"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Mac/share"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Mac/pkgconfig"

echo -e "Removing unused libraries...\n"
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Mac/libgrpc++_unsecure.a" # We use libgrpc++.a
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Mac/libgrpc_unsecure.a" # We use libgrpc.a
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Mac/libgrpc++_reflection.a" # Not needed
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Mac/libgrpc_authorization_provider.a" # Not needed
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Mac/libprotobuf.a" # We use libprotobuf-lite.a
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Mac/libgrpc_plugin_support.a" # Only needed during build of grpc code gen plugins
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Mac/libprotoc.a" # Only needed during build of grpc code gen plugins
rm -f "$ROOT_DIR/Output/gRPC/Libraries/Mac/libutf8_range_lib.a" # Redundant with libutf8_range.a

# We want to re-export all symbols from these libraries through one Unreal dll.
# libupb_json_lib.a and libupb_textformat_lib.a for some reason have symbols in common with libgrpc.a. So we don't want to force them to load.
find "$ROOT_DIR/Output/gRPC/Libraries/Mac" -type f -name "*.a" ! -name "libupb_json_lib.a" ! -name "libupb_textformat_lib.a" -exec basename {} \; > "$ROOT_DIR/Output/gRPC/Libraries/Mac/exports.def"

echo -e "Archiving outputs...\n"
ARCHIVE="$ROOT_DIR/Release/TempoThirdParty-Mac-$TAG.tar.gz"
rm -rf "$ARCHIVE"
tar -C "$ROOT_DIR/Output" -czf "$ARCHIVE" gRPC

echo "Done! Archive: $ARCHIVE"
