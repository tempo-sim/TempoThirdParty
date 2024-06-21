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

# Check for boost-python3
if ! brew ls boost-python3; then
    echo "Couldn't find boost-python3. Please install (brew install boost-python3)."
    exit 1
fi

# Check for theora
if ! brew ls theora; then
    echo "Couldn't find theora. Please install (brew install theora)."
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
pip install netifaces

echo "Applying Tempo patches..."
cd "$ROOT_DIR/Source/rclcpp/rcpputils"
git reset --hard && git apply "$ROOT_DIR/Patches/rcpputils.patch"
cd "$ROOT_DIR/Source/rclcpp/rclcpp"
git reset --hard && git apply "$ROOT_DIR/Patches/rclcpp.patch"
cd "$ROOT_DIR/Source/rclcpp/rmw"
git reset --hard && git apply "$ROOT_DIR/Patches/rmw.patch"

echo "Building rclcpp..."
mkdir -p "$ROOT_DIR/Builds/rclcpp/Mac"
cd "$ROOT_DIR/Source/rclcpp"

mkdir -p "$ROOT_DIR/Outputs/rclcpp/Binaries/Mac"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Libraries/Mac"
mkdir -p "$ROOT_DIR/Outputs/rclcpp/Includes"

colcon build --packages-skip-by-dep python_qt_binding \
 --build-base "$ROOT_DIR/Builds/rclcpp/Mac" \
 --install-base "$ROOT_DIR/Builds/rclcpp/Mac" \
 --merge-install \
 --catkin-skip-building-tests \
 --cmake-args \
 -DCMAKE_POLICY_DEFAULT_CMP0148=OLD \
 -DCMAKE_CXX_FLAGS="-Wno-error=strict-prototypes -Wno-error=deprecated-copy \
                    -fexceptions -DPLATFORM_EXCEPTIONS_DISABLED=0 -fmessage-length=0 \
                    -fpascal-strings -fasm-blocks -ffp-contract=off -isystem /opt/homebrew/include" \
 -DCMAKE_OSX_ARCHITECTURES="arm64" -DCMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
 -DBoost_NO_BOOST_CMAKE=ON \
 -DTRACETOOLS_DISABLED=ON \
 -DCMAKE_SHARED_LINKER_FLAGS=" -ld_classic" \
 --no-warn-unused-cli

DEST="$ROOT_DIR/Outputs/rclcpp"

# Copy the binaries
cp -r -P "$ROOT_DIR/Source/rclcpp/install/bin"/* "$DEST/Binaries/Mac"

# Copy the libraries
find "$ROOT_DIR/Source/rclcpp/install" -name "*.dylib" -exec cp -P {} "$DEST/Libraries/Mac" \;

# Copy the Python framework we linked against
cd "$ROOT_DIR/Source/rclcpp"
PYPATH=$(./python3-config --prefix)
PY3FRAMEWORK="${PYPATH%%Versions*}"
PY3FRAMEWORK=$(echo "$PY3FRAMEWORK" | sed 's:/*$::')
cp -r -P "$PY3FRAMEWORK" "$DEST/Libraries/Mac"

# Copy the "share" folder
cp -r -P "$ROOT_DIR/Source/rclcpp/install/share" "$DEST/Libraries/Mac"

# Copy the includes
INCLUDE_DIRS=$(find "$ROOT_DIR/Source/rclcpp/install/include" -type d -maxdepth 1 -mindepth 1)
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
