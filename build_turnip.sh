#!/bin/bash

# Script to cross-compile Mesa for ARM64 and ARMHF with Vulkan KGSL driver
# Target: ARM64 and ARMHF (armv7hf) for Android

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
WHITE='\033[0;37m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Get Mesa version from argument, environment variable, or default to 24.0.2
MESA_VERSION="${1:-${MESA_VERSION:-24.0.2}}"
echo -e "${GREEN}Starting Mesa cross-compilation for ARM64 and ARMHF (version $MESA_VERSION)...${NC}"

# Set working directory and Mesa tarball details
WORK_DIR="${HOME}/mesa-main"
MESA_TARBALL="mesa-mesa-$MESA_VERSION.tar.gz"
MESA_URL="https://gitlab.freedesktop.org/mesa/mesa/-/archive/mesa-$MESA_VERSION/$MESA_TARBALL"
MESA_SRC_DIR="$WORK_DIR/mesa-$MESA_VERSION"

# Ensure working directory exists
mkdir -p "$WORK_DIR" || {
    echo -e "${RED}Error: Failed to create working directory $WORK_DIR${NC}" >&2
    exit 1
}
cd "$WORK_DIR" || {
    echo -e "${RED}Error: Failed to change to working directory $WORK_DIR${NC}" >&2
    exit 1
}

# Download Mesa tarball if not present
if [ ! -f "$MESA_TARBALL" ]; then
    echo -e "${GREEN}Downloading Mesa $MESA_VERSION...${NC}"
    wget --continue "$MESA_URL" || {
        echo -e "${RED}Error: Failed to download Mesa $MESA_VERSION from $MESA_URL${NC}" >&2
        exit 1
    }
fi

# Extract tarball if source directory doesn't exist
if [ ! -d "$MESA_SRC_DIR" ]; then
    echo -e "${GREEN}Extracting Mesa $MESA_VERSION...${NC}"
    tar -xf "$MESA_TARBALL" -C "$WORK_DIR" || {
        echo -e "${RED}Error: Failed to extract $MESA_TARBALL${NC}" >&2
        exit 1
    }
fi

# Function to build Mesa for a specific architecture
build_mesa() {
    local ARCH=$1
    local TRIPLE=$2
    local CROSS_FILE="$WORK_DIR/cross-$ARCH.ini"
    local BUILD_DIR="$WORK_DIR/build-$ARCH"
    local INSTALL_DIR="$WORK_DIR/install-$ARCH"
    local OUTPUT_TARBALL="$WORK_DIR/mesa-$MESA_VERSION-$ARCH.tar.gz"

    # Ensure cross-file exists
    if [ ! -f "$CROSS_FILE" ]; then
        echo -e "${RED}Error: Cross-compilation file $CROSS_FILE not found${NC}" >&2
        exit 1
    }

    echo -e "${GREEN}Configuring Mesa for $ARCH...${NC}"
    cd "$MESA_SRC_DIR" || {
        echo -e "${RED}Error: Failed to change to $MESA_SRC_DIR${NC}" >&2
        exit 1
    }

    meson setup "$BUILD_DIR" \
        --cross-file "$CROSS_FILE" \
        --prefix=/usr \
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
        -Dbuildtype=release || {
            echo -e "${RED}Error: Meson setup failed for $ARCH${NC}" >&2
            exit 1
        }

    echo -e "${GREEN}Building Mesa for $ARCH...${NC}"
    ninja -C "$BUILD_DIR" || {
        echo -e "${RED}Error: Compilation failed for $ARCH${NC}" >&2
        exit 1
    }

    echo -e "${GREEN}Installing Mesa for $ARCH...${NC}"
    mkdir -p "$INSTALL_DIR" || {
        echo -e "${RED}Error: Failed to create install directory $INSTALL_DIR${NC}" >&2
        exit 1
    }
    DESTDIR="$INSTALL_DIR" ninja -C "$BUILD_DIR" install || {
        echo -e "${RED}Error: Installation failed for $ARCH${NC}" >&2
        exit 1
    }

    echo -e "${GREEN}Packaging $ARCH build...${NC}"
    tar -C "$INSTALL_DIR" -czf "$OUTPUT_TARBALL" . || {
        echo -e "${RED}Error: Failed to create tarball $OUTPUT_TARBALL${NC}" >&2
        exit 1
    }
}

# Create cross-compilation config files if they don't exist
if [ ! -f "$WORK_DIR/cross-arm64.ini" ]; then
    echo -e "${GREEN}Creating cross-compilation config for arm64...${NC}"
    cat > "$WORK_DIR/cross-arm64.ini" << EOF
[binaries]
c = 'aarch64-linux-gnu-gcc'
cpp = 'aarch64-linux-gnu-g++'
ar = 'aarch64-linux-gnu-ar'
strip = 'aarch64-linux-gnu-strip'
pkgconfig = 'pkg-config'
pkg_config_path = '/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig'

[host_machine]
system = 'linux'
cpu_family = 'arm64'
cpu = 'armv8-a'
endian = 'little'
EOF
fi

if [ ! -f "$WORK_DIR/cross-armhf.ini" ]; then
    echo -e "${GREEN}Creating cross-compilation config for armhf...${NC}"
    cat > "$WORK_DIR/cross-armhf.ini" << EOF
[binaries]
c = 'arm-linux-gnueabihf-gcc'
cpp = 'arm-linux-gnueabihf-g++'
ar = 'arm-linux-gnueabihf-ar'
strip = 'arm-linux-gnueabihf-strip'
pkgconfig = 'pkg-config'
pkg_config_path = '/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/share/pkgconfig'

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7-a'
endian = 'little'
EOF
fi

# Build for ARM64
echo -e "${GREEN}Starting ARM64 build...${NC}"
build_mesa "arm64" "aarch64-linux-gnu"

# Build for ARMHF (armv7hf)
echo -e "${GREEN}Starting ARMHF build...${NC}"
build_mesa "armhf" "arm-linux-gnueabihf"

# Clean up source (optional, commented out by default)
# echo -e "${GREEN}Cleaning up source directory...${NC}"
# rm -rf "$MESA_SRC_DIR"

echo -e "${GREEN}Mesa $MESA_VERSION cross-compiled for ARM64 and ARMHF successfully!${NC}"
echo -e "${GREEN}Output files:${NC}"
echo -e "  - $WORK_DIR/mesa-$MESA_VERSION-arm64.tar.gz (for ARM64)"
echo -e "  - $WORK_DIR/mesa-$MESA_VERSION-armhf.tar.gz (for ARMHF)"
