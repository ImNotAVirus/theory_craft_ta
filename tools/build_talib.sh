#!/bin/bash
# Build script for ta-lib C library on Linux/macOS
# Based on ta-lib-python build scripts

set -e

TALIB_VERSION="${TALIB_VERSION:-0.6.4}"
INSTALL_DIR="$(pwd)/ta-lib-install"

echo "Building TA-Lib version ${TALIB_VERSION}"
echo "Install directory: ${INSTALL_DIR}"

# Download TA-Lib from GitHub
echo "Downloading TA-Lib ${TALIB_VERSION}..."
curl -L -o "talib-${TALIB_VERSION}.zip" "https://github.com/TA-Lib/ta-lib/archive/refs/tags/v${TALIB_VERSION}.zip"

if [ $? -ne 0 ]; then
    echo "Error: Failed to download TA-Lib"
    exit 1
fi

# Extract archive
echo "Extracting archive..."
unzip -q "talib-${TALIB_VERSION}.zip"

if [ $? -ne 0 ]; then
    echo "Error: Failed to extract TA-Lib"
    exit 1
fi

# Navigate to extracted directory
cd "ta-lib-${TALIB_VERSION}"

# Copy headers to include/ta-lib/ subdirectory (needed for includes)
echo "Copying headers..."
mkdir -p include/ta-lib
cp include/*.h include/ta-lib/

# Create build directory
mkdir -p _build
cd _build

# Configure with CMake
echo "Configuring with CMake..."

# Use CMAKE_ARGS from environment if set, otherwise default
CMAKE_ARGS="${CMAKE_ARGS:--DCMAKE_BUILD_TYPE=Release}"
CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}"

cmake $CMAKE_ARGS ..

if [ $? -ne 0 ]; then
    echo "Error: CMake configuration failed"
    exit 1
fi

# Build
echo "Building TA-Lib..."
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)

if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi

# Install
echo "Installing to ${INSTALL_DIR}..."
make install

if [ $? -ne 0 ]; then
    echo "Error: Install failed"
    exit 1
fi

echo "TA-Lib ${TALIB_VERSION} built and installed successfully!"
echo "Library location: ${INSTALL_DIR}/lib"
echo "Headers location: ${INSTALL_DIR}/include"
