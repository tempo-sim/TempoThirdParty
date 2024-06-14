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
    echo "Couldn't find brew. Please install (https://brew.sh/)"
    exit 1
fi

# Check for tinyxml2
if ! brew ls tinyxml2; then
    echo "Couldn't find tinyxml2. Please install (brew install tinyxml2)."
    exit 1
fi

# Check for asio
if ! brew ls asio; then
    echo "Couldn't find asio. Please install (brew install asio)."
    exit 1
fi

# Check for tag
TAG=$(git name-rev --tags --name-only "$(git rev-parse HEAD)")
if [ "$TAG" = "undefined" ]; then
    echo "Could not find git tag"
    exit 1
fi

echo -e "Using git tag: $TAG\n"

echo -e "All prerequisites satisfied. Starting build.\n"

NUM_JOBS="$(sysctl -n hw.ncpu)"
echo -e "Detected $NUM_JOBS processors. Will use $NUM_JOBS jobs.\n"

echo -e "Removing stale Outputs and Builds\n"
rm -rf "$ROOT_DIR/Outputs/rclcpp"
rm -rf "$ROOT_DIR/Builds/rclcpp"

echo -e "Creating Python virtual environment for build.\n"
python3 -m venv "$ROOT_DIR/Builds/rclcpp/venv"
cp "$ROOT_DIR/Source/rclcpp/python3-config" "$ROOT_DIR/Builds/rclcpp/venv/bin"
source "$ROOT_DIR/Builds/rclcpp/venv/bin/activate"
pip install colcon-common-extensions
pip install lark==1.1.1
pip install numpy

echo "Applying Tempo patches..."
cd "$ROOT_DIR/Source/rclcpp/rcpputils"
git reset --hard && git apply "$ROOT_DIR/Patches/rcpputils.patch"

echo "Building rclcpp..."
mkdir -p "$ROOT_DIR/Builds/rclcpp/Mac"
cd "$ROOT_DIR/Source/rclcpp"

 #--install-base "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac" 
colcon build --packages-skip-by-dep python_qt_binding \
 --build-base "$ROOT_DIR/Builds/rclcpp/Mac" \
 --ament-cmake-args \
 -DCMAKE_POLICY_DEFAULT_CMP0148=OLD \
 -DCMAKE_CXX_FLAGS="-Wno-error=strict-prototypes -Wno-error=deprecated-copy" --no-warn-unused-cli

mkdir -p "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Includes"

find "$ROOT_DIR/Source/rclcpp/install" -type f -name "*.dylib" -exec cp {} "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac" \;
find "$ROOT_DIR/Source/rclcpp/install" -type d -maxdepth 1 -exec bash -c '[[ -e "$1/include/$(basename $1)" ]] && cp -r "$1/include/$(basename $1)" "$2/Outputs/rclcpp/Includes"' _ {} "$ROOT_DIR" \;
#INCLUDE_DIRS=$(find "$ROOT_DIR/Source/rclcpp/install" -type d -name include)
#for INCLUDE_DIR in $INCLUDE_DIRS; do
#  echo "copy"
#  rsync -r "$INCLUDE_DIR"/* "$ROOT_DIR/Outputs/rclcpp/Includes"
#done
  
#echo -e "Cleaning up output directory...\n"
#rm -rf "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/cmake"
#rm -rf "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/share"
#rm -rf "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/pkgconfig"

#echo -e "Removing unused libraries...\n"
#rm -f "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/librclcpp++_unsecure.a" # We use librclcpp++.a
#rm -f "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/librclcpp_unsecure.a" # We use librclcpp.a
#rm -f "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/libprotobuf-lite.a" # We use libprotobuf.a
#rm -f "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/librclcpp_plugin_support.a" # Only needed during build of rclcpp code gen plugins
#rm -f "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/libprotoc.a" # Only needed during build of rclcpp code gen plugins
#rm -f "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac/libutf8_range_lib.a" # Redundant with libutf8_range.a

echo -e "Archiving outputs...\n"
ARCHIVE="$ROOT_DIR/Releases/TempoThirdParty-rclcpp-Mac-$TAG.tar.gz"
rm -rf "$ARCHIVE"
tar -C "$ROOT_DIR/Outputs" -czf "$ARCHIVE" rclcpp

echo "Done! Archive: $ARCHIVE"
