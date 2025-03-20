#!/bin/bash

# Script to cross-compile Mesa for ARM64 and ARMHF with Vulkan KGSL driver
# Target: ARM64 (aarch64) and ARMHF (armv7hf) for Android
# Run on: GitHub Actions Ubuntu runner
# Date: March 19, 2025

# Exit on any error
set -e

# Colors for output (visible in GitHub Actions logs)
GREEN='\033[0;32m'
WHITE='\033[0;37m'
RED='\033[0;31m'

echo -e "${GREEN}Starting Mesa cross-compilation for ARM64 and ARMHF...${WHITE}"

# Set working directory and Mesa version
WORK_DIR="$HOME/mesa-cross-build"
MESA_VERSION="24.0.2"  # Official stable release (adjust as needed)
MESA_TARBALL="mesa-$MESA_VERSION.tar.xz"
MESA_URL="https://archive.mesa3d.org/$MESA_TARBALL"

# Create working directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Download Mesa tarball
if [ ! -f "$MESA_TARBALL" ]; then
    echo -e "${GREEN}Downloading Mesa $MESA_VERSION...${WHITE}"
    wget "$MESA_URL"
fi

# Extract tarball (shared for both builds)
if [ ! -d "mesa-$MESA_VERSION" ]; then
    echo -e "${GREEN}Extracting Mesa $MESA_VERSION...${WHITE}"
    tar -xJf "$MESA_TARBALL"
fi

# Function to build for a specific architecture
build_mesa() {
    local ARCH=$1
    local TRIPLE=$2
    local BUILD_DIR="build-$ARCH"
    local INSTALL_DIR="$WORK_DIR/install-$ARCH"

    echo -e "${GREEN}Configuring Mesa for $ARCH...${WHITE}"
    cd "$WORK_DIR/mesa-$MESA_VERSION"
    
    meson setup "$BUILD_DIR" \
        --cross-file "$WORK_DIR/cross-$ARCH.ini" \
        -Dgbm=enabled \
        -Dopengl=true \
        -Degl=enabled \
        -Degl-native-platform=x11 \
        -Dgles1=disabled \
        -Dgles2=enabled \
        -Ddri3=enabled \
        -Dglx=dri \
        -Dllvm=enabled \
        -Dshared-llvm=disabled \
        -Dplatforms=x11,wayland \
        -Dgallium-drivers=swrast,virgl,zink \
        -Dosmesa=true \
        -Dglvnd=true \
        -Dxmlconfig=disabled \
        -Dbuildtype=release \
        -Dprefix="$INSTALL_DIR"

    echo -e "${GREEN}Building Mesa for $ARCH...${WHITE}"
    ninja -C "$BUILD_DIR"

    echo -e "${GREEN}Installing Mesa for $ARCH...${WHITE}"
    ninja -C "$BUILD_DIR" install

    echo -e "${GREEN}Packaging $ARCH build...${WHITE}"
    tar -C "$INSTALL_DIR" -czf "$WORK_DIR/mesa-$MESA_VERSION-$ARCH.tar.gz" .
}

# Create cross-compilation config files
cat > "$WORK_DIR/cross-aarch64.ini" << EOF
[binaries]
c = 'aarch64-linux-gnu-gcc'
cpp = 'aarch64-linux-gnu-g++'
ar = 'aarch64-linux-gnu-ar'
strip = 'aarch64-linux-gnu-strip'
pkgconfig = 'aarch64-linux-gnu-pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF

cat > "$WORK_DIR/cross-armhf.ini" << EOF
[binaries]
c = 'arm-linux-gnueabihf-gcc'
cpp = 'arm-linux-gnueabihf-g++'
ar = 'arm-linux-gnueabihf-ar'
strip = 'arm-linux-gnueabihf-strip'
pkgconfig = 'arm-linux-gnueabihf-pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7-a'
endian = 'little'
EOF

# Build for ARM64 (aarch64)
echo -e "${GREEN}Starting ARM64 build...${WHITE}"
build_mesa "aarch64" "aarch64-linux-gnu"

# Build for ARMHF (armv7hf)
echo -e "${GREEN}Starting ARMHF build...${WHITE}"
build_mesa "armhf" "arm-linux-gnueabihf"

# Clean up source (optional)
echo -e "${GREEN}Cleaning up source directory...${WHITE}"
rm -rf "$WORK_DIR/mesa-$MESA_VERSION"

echo -e "${GREEN}Mesa $MESA_VERSION cross-compiled for ARM64 and ARMHF successfully!${WHITE}"
echo -e "${GREEN}Output files:${WHITE}"
echo -e "  - $WORK_DIR/mesa-$MESA_VERSION-aarch64.tar.gz (for ARM64)"
echo -e "  - $WORK_DIR/mesa-$MESA_VERSION-armhf.tar.gz (for ARMHF)"
