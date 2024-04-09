#!/usr/bin/env bash

set -e

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
if ! TAG=$(git describe --tags); then
    echo "Could not find git tag";
    exit 1
fi

echo -e "Using git tag: $TAG\n";

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

echo "All prerequisites satisfied. Starting build."

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR="$SCRIPT_DIR/.."

echo "Removing contents of Output folder"
find "$ROOT_DIR/Output" -type d -maxdepth 1 -mindepth 1 -exec rm -rf {} \;

echo -e "\nBuilding re2..."
cd "$ROOT_DIR/Source/re2"
git reset --hard && git apply "$ROOT_DIR/Patch/re2.patch"
mkdir -p "$ROOT_DIR/Build/Mac/re2" && cd "$ROOT_DIR/Build/Mac/re2"
cmake -G "Unix Makefiles" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/RE2" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchains/apple.toolchain.cmake" \
 -DCMAKE_INSTALL_LIBDIR="Libraries/Mac" -DPLATFORM=MAC_UNIVERSAL -DDEPLOYMENT_TARGET=10.14 \
 -DCMAKE_INSTALL_CMAKEDIR="Libraries/Mac/cmake" \
 -DCMAKE_CXX_STANDARD=17 -DRE2_BUILD_TESTING=OFF \
 "$ROOT_DIR/Source/re2"
cmake --build . --target install --config Release
echo -e "Successfully built re2.\n"

echo -e "Building abseil-cpp..."
cd "$ROOT_DIR/Source/abseil-cpp"
git reset --hard && git apply "$ROOT_DIR/Patch/abseil-cpp.patch"
mkdir -p "$ROOT_DIR/Build/Mac/abseil-cpp" && cd "$ROOT_DIR/Build/Mac/abseil-cpp"
cmake -G "Unix Makefiles" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/Abseil" \
 -DCMAKE_INSTALL_LIBDIR="Libraries/Mac" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchains/apple.toolchain.cmake" \
 -DPLATFORM=MAC_UNIVERSAL -DDEPLOYMENT_TARGET=10.14 \
 -DCMAKE_INSTALL_CMAKEDIR="Libraries/Mac/cmake" \
 -DCMAKE_CXX_STANDARD=17 -DBUILD_TESTING=False -DABSL_PROPAGATE_CXX_STD=True \
 "$ROOT_DIR/Source/abseil-cpp"
cmake --build . --target install --config Release
echo -e "Successfully built abseil-cpp.\n"

echo -e "Building protobuf..."
cd "$ROOT_DIR/Source/protobuf"
git reset --hard && git apply "$ROOT_DIR/Patch/protobuf.patch"
mkdir -p "$ROOT_DIR/Build/Mac/protobuf" && cd "$ROOT_DIR/Build/Mac/protobuf"
cmake -G "Unix Makefiles" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/Protobuf" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchains/apple.toolchain.cmake" \
 -DCMAKE_INSTALL_LIBDIR="Libraries/Mac" -DPLATFORM=MAC_UNIVERSAL -DDEPLOYMENT_TARGET=10.14 \
 -DCMAKE_INSTALL_CMAKEDIR="Libraries/Mac/cmake" -DCMAKE_CXX_STANDARD=17 \
 -Dprotobuf_BUILD_TESTS=false -Dprotobuf_WITH_ZLIB=false \
 -Dprotobuf_BUILD_EXAMPLES=false \
 -Dprotobuf_BUILD_PROTOC_BINARIES=true -Dprotobuf_BUILD_LIBPROTOC=true \
 -Dprotobuf_ABSL_PROVIDER=package -Dabsl_DIR="$ROOT_DIR/Output/Abseil/Libraries/Mac/cmake" \
 "$ROOT_DIR/Source/protobuf"
cmake --build . --target install --config Release
echo -e "Successfully built protobuf.\n"

echo -e "Building gRPC..."
cd "$ROOT_DIR/Source/gRPC"
git reset --hard && git apply "$ROOT_DIR/Patch/gRPC.patch"
mkdir -p "$ROOT_DIR/Build/Mac/gRPC" && cd "$ROOT_DIR/Build/Mac/gRPC"
cmake -G "Unix Makefiles" \
 -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/Output/gRPC" \
 -DgRPC_INSTALL_LIBDIR="Libraries/Mac" -DgRPC_INSTALL_CMAKEDIR="Libraries/Mac/cmake" \
 -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/Toolchains/apple.toolchain.cmake" \
 -DPLATFORM=MAC_UNIVERSAL -DDEPLOYMENT_TARGET=10.14 -DCMAKE_CXX_STANDARD=17 \
 -DgRPC_ABSL_PROVIDER=package -Dabsl_DIR="$ROOT_DIR/Output/Abseil/Libraries/Mac/cmake" \
 -DgRPC_RE2_PROVIDER=package -Dre2_DIR="$ROOT_DIR/Output/RE2/Libraries/Mac/cmake" \
 -DgRPC_PROTOBUF_PROVIDER=package \
 -DProtobuf_DIR="$ROOT_DIR/Output/Protobuf/Libraries/Mac/cmake" \
 -Dutf8_range_DIR="$ROOT_DIR/Output/Protobuf/Libraries/Mac/cmake" \
 -DgRPC_USE_CARES=OFF -DgRPC_ZLIB_PROVIDER=package \
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
 -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF -D_gRPC_CPP_PLUGIN="$ROOT_DIR/Build/Mac/gRPC/grpc_cpp_plugin.app/Contents/MacOS/grpc_cpp_plugin" \
 -D_gRPC_PROTOBUF_PROTOC_EXECUTABLE="$ROOT_DIR/Output/Protobuf/bin/protoc.app/Contents/MacOS/protoc" \
 -DPACKAGE_PREFIX_DIR="$ROOT_DIR/Output/RE2" \
 "$ROOT_DIR/Source/gRPC"
cmake --build . --target install --config Release
echo -e "Successfully built gRPC.\n"

echo -e "Cleaning up Output directory...\n"
mv "$ROOT_DIR/Output/RE2/include" "$ROOT_DIR/Output/RE2/Includes"
rm -rf "$ROOT_DIR/Output/RE2/Libraries/Mac/cmake"
mv "$ROOT_DIR/Output/Abseil/include" "$ROOT_DIR/Output/Abseil/Includes"
rm -rf "$ROOT_DIR/Output/Abseil/Libraries/Mac/cmake"
mv "$ROOT_DIR/Output/Protobuf/include" "$ROOT_DIR/Output/Protobuf/Includes"
mv "$ROOT_DIR/Output/Protobuf/bin" "$ROOT_DIR/Output/Protobuf/Binaries"
rm -rf "$ROOT_DIR/Output/Protobuf/Libraries/Mac/cmake"
rm -rf "$ROOT_DIR/Output/Protobuf/Libraries/Mac/pkgconfig"
mv "$ROOT_DIR/Output/Protobuf/Binaries/protoc.app/Contents/MacOS/protoc" "$ROOT_DIR/Output/Protobuf/Binaries"
rm -rf "$ROOT_DIR/Output/Protobuf/Binaries/protoc.app"
mv "$ROOT_DIR/Output/gRPC/include" "$ROOT_DIR/Output/gRPC/Includes"
mv "$ROOT_DIR/Output/gRPC/bin" "$ROOT_DIR/Output/gRPC/Binaries"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Mac/cmake"
rm -rf "$ROOT_DIR/Output/gRPC/share"
rm -rf "$ROOT_DIR/Output/gRPC/Libraries/Mac/pkgconfig"
mv "$ROOT_DIR/Output/gRPC/Binaries/grpc_cpp_plugin.app/Contents/MacOS/grpc_cpp_plugin" "$ROOT_DIR/Output/gRPC/Binaries"
rm -rf "$ROOT_DIR/Output/gRPC/Binaries/grpc_cpp_plugin.app"
mv "$ROOT_DIR/Output/gRPC/Binaries/grpc_python_plugin.app/Contents/MacOS/grpc_python_plugin" "$ROOT_DIR/Output/gRPC/Binaries"
rm -rf "$ROOT_DIR/Output/gRPC/Binaries/grpc_python_plugin.app"

ditto -ck "$ROOT_DIR/Output" "$ROOT_DIR/Output/TempoThirdParty-Mac-$TAG.zip"

echo "Done! Archive: $ROOT_DIR/Output/TempoThirdParty-Mac-$TAG.zip"
