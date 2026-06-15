#!/bin/bash

# Script to cross-compile Mesa for ARM64 and ARMHF with Vulkan KGSL driver
# Target: ARM64 and ARMHF (armv7hf) for Termux's Proot System

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
WHITE='\033[0;37m'
RED='\033[0;31m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------
# $1 — Mesa version (e.g. 24.3.4)
# $2 — Arch filter: arm64 | armhf | all (default: all)
#      Pass a single arch when invoking from a matrix job so each runner only
#      builds its own target and the two builds run in parallel.
# ---------------------------------------------------------------------------
MESA_VERSION="${1:-${MESA_VERSION:-24.3.4}}"
ARCH_FILTER="${2:-all}"

BUILD_DATE=$(date +"%F" | sed 's/-//g')
echo -e "${GREEN}Starting Mesa cross-compilation (version $MESA_VERSION, arch: $ARCH_FILTER)...${NC}"

MESA_TARBALL="mesa-mesa-$MESA_VERSION.tar.gz"
MESA_URL="https://gitlab.freedesktop.org/mesa/mesa/-/archive/mesa-$MESA_VERSION/$MESA_TARBALL"

WORK_DIR="${HOME}/mesa-$MESA_VERSION"
MESA_SRC_DIR="$WORK_DIR/mesa-$MESA_VERSION-src"
OUTPUT_DIR="${HOME}/mesa-build"
PATCHES_DIR="${GITHUB_WORKSPACE:-$(pwd)}/patches"

mkdir -p "$WORK_DIR" || { echo -e "${RED}Error: Failed to create $WORK_DIR${NC}" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR" || { echo -e "${RED}Error: Failed to create $OUTPUT_DIR${NC}" >&2; exit 1; }
cd "$WORK_DIR" || { echo -e "${RED}Error: Failed to cd to $WORK_DIR${NC}" >&2; exit 1; }

# ---------------------------------------------------------------------------
# ccache — speeds up repeated compiles dramatically. Optional: the build
# continues without it if ccache is not installed.
# ---------------------------------------------------------------------------
if command -v ccache &>/dev/null; then
    USE_CCACHE=true
    export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.ccache}"
    export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-2G}"
    # Slimline stats reset so the post-build "show-stats" output is per-run.
    ccache --zero-stats
    echo -e "${GREEN}ccache enabled (cache dir: $CCACHE_DIR, max: $CCACHE_MAXSIZE)${NC}"
else
    USE_CCACHE=false
    echo -e "${WHITE}ccache not found — building without compiler cache${NC}"
fi

# ---------------------------------------------------------------------------
# Download Mesa source
# ---------------------------------------------------------------------------
if [ ! -f "$MESA_TARBALL" ]; then
    echo -e "${GREEN}Downloading Mesa $MESA_VERSION...${NC}"
    wget --continue "$MESA_URL" || { echo -e "${RED}Error: Download failed from $MESA_URL${NC}" >&2; exit 1; }
fi

# ---------------------------------------------------------------------------
# Extract
# ---------------------------------------------------------------------------
if [ ! -d "$MESA_SRC_DIR" ]; then
    echo -e "${GREEN}Extracting Mesa $MESA_VERSION into $MESA_SRC_DIR...${NC}"
    mkdir -p "$MESA_SRC_DIR" || { echo -e "${RED}Error: Failed to create $MESA_SRC_DIR${NC}" >&2; exit 1; }
    tar -xf "$MESA_TARBALL" --strip-components=1 -C "$MESA_SRC_DIR" || {
        echo -e "${RED}Error: Extraction failed${NC}" >&2; exit 1
    }
    rm -rf "$MESA_SRC_DIR/subprojects"
fi

# ---------------------------------------------------------------------------
# Patches
# ---------------------------------------------------------------------------
if [ "$USE_PATCHES" = "true" ]; then
    if [ -d "$PATCHES_DIR" ]; then
        echo -e "${GREEN}Applying patches from $PATCHES_DIR...${NC}"
        cd "$MESA_SRC_DIR" || { echo -e "${RED}Error: Failed to cd to $MESA_SRC_DIR${NC}" >&2; exit 1; }
        for patch in "$PATCHES_DIR"/*.patch; do
            if [ -f "$patch" ]; then
                echo -e "${GREEN}Applying patch: $(basename "$patch")${NC}"
                patch -p1 < "$patch" || \
                    echo -e "${WHITE}Warning: Failed to apply $(basename "$patch"), continuing...${NC}" >&2
            else
                echo -e "${WHITE}No .patch files found in $PATCHES_DIR${NC}"
                break
            fi
        done
        cd "$WORK_DIR"
    else
        echo -e "${WHITE}No patches directory at $PATCHES_DIR, skipping${NC}"
    fi
else
    echo -e "${WHITE}USE_PATCHES is false, skipping patch application${NC}"
fi

# ---------------------------------------------------------------------------
# generate_cross_file ARCH
#   Writes a meson cross-compilation .ini for the given arch.
#   Wraps the compiler with ccache when available.
# ---------------------------------------------------------------------------
generate_cross_file() {
    local ARCH=$1
    local CROSS_FILE="$WORK_DIR/cross-$ARCH.ini"

    [ -f "$CROSS_FILE" ] && return 0

    local CC CXX AR STRIP PKG_CONFIG CPU_FAMILY CPU

    if [ "$ARCH" = "arm64" ]; then
        CC="aarch64-linux-gnu-gcc"
        CXX="aarch64-linux-gnu-g++"
        AR="aarch64-linux-gnu-ar"
        STRIP="aarch64-linux-gnu-strip"
        PKG_CONFIG="aarch64-linux-gnu-pkg-config"
        CPU_FAMILY="aarch64"
        CPU="aarch64"
    else
        CC="arm-linux-gnueabihf-gcc"
        CXX="arm-linux-gnueabihf-g++"
        AR="arm-linux-gnueabihf-ar"
        STRIP="arm-linux-gnueabihf-strip"
        PKG_CONFIG="arm-linux-gnueabihf-pkg-config"
        CPU_FAMILY="arm"
        CPU="arm"
    fi

    # Meson accepts a list for the compiler entry, which is how we inject ccache.
    local C_ENTRY CPP_ENTRY
    if [ "$USE_CCACHE" = "true" ]; then
        C_ENTRY="c = ['ccache', '$CC']"
        CPP_ENTRY="cpp = ['ccache', '$CXX']"
    else
        C_ENTRY="c = '$CC'"
        CPP_ENTRY="cpp = '$CXX'"
    fi

    echo -e "${GREEN}Creating cross-compilation config for $ARCH...${NC}"
    cat > "$CROSS_FILE" << EOF
[binaries]
$C_ENTRY
$CPP_ENTRY
ar = '$AR'
strip = '$STRIP'
pkg-config = '$PKG_CONFIG'

[host_machine]
system = 'linux'
cpu_family = '$CPU_FAMILY'
cpu = '$CPU'
endian = 'little'
EOF
}

# ---------------------------------------------------------------------------
# build_mesa ARCH
# ---------------------------------------------------------------------------
build_mesa() {
    local ARCH=$1
    local CROSS_FILE="$WORK_DIR/cross-$ARCH.ini"
    local BUILD_DIR="$WORK_DIR/build-$ARCH"
    local INSTALL_DIR="$WORK_DIR/install-$ARCH"
    local OUTPUT_FILE="$OUTPUT_DIR/mesa-vulkan-kgsl_$MESA_VERSION-$BUILD_DATE-$ARCH.deb"

    # Arch-specific layout variables.
    local LIBDIR ICD_JSON
    if [ "$ARCH" = "arm64" ]; then
        LIBDIR="lib/aarch64-linux-gnu"
        ICD_JSON="freedreno_icd.aarch64.json"
    else
        LIBDIR="lib/arm-linux-gnueabihf"
        # Mesa names this after the cpu field in the cross file ('arm').
        ICD_JSON="freedreno_icd.arm.json"
    fi

    if [ ! -f "$CROSS_FILE" ]; then
        echo -e "${RED}Error: Cross-compilation file $CROSS_FILE not found${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Configuring Mesa for $ARCH...${NC}"
    cd "$MESA_SRC_DIR" || { echo -e "${RED}Error: Failed to cd to $MESA_SRC_DIR${NC}" >&2; exit 1; }

    meson setup "$BUILD_DIR" --cross-file "$CROSS_FILE" --prefix /usr --libdir "$LIBDIR" \
        -Dplatforms=x11,wayland -Dgallium-drivers=freedreno \
        -Dvulkan-drivers=freedreno -Dfreedreno-kmds=msm,kgsl \
        -Dglx=disabled -Degl=disabled -Dgles1=disabled -Dgles2=disabled \
        -Dopengl=false -Dshared-glapi=disabled -Dgbm=disabled \
        -Dllvm=disabled -Dshared-llvm=disabled -Dxmlconfig=disabled \
        -Db_lto=true -Db_lto_mode=thin -Dcpp_rtti=false -Dstrip=true \
        -Dbuildtype=release || {
        echo -e "${RED}Error: Meson setup failed for $ARCH${NC}" >&2; exit 1
    }

    echo -e "${GREEN}Building Mesa for $ARCH...${NC}"
    # -j$(nproc) is the meson default but being explicit avoids any edge cases
    # where meson falls back to a single thread.
    meson compile -C "$BUILD_DIR" -j"$(nproc)" || {
        echo -e "${RED}Error: Compilation failed for $ARCH${NC}" >&2; exit 1
    }

    echo -e "${GREEN}Installing Mesa for $ARCH...${NC}"
    mkdir -p "$INSTALL_DIR" || { echo -e "${RED}Error: Failed to create $INSTALL_DIR${NC}" >&2; exit 1; }
    meson install -C "$BUILD_DIR" --destdir "${INSTALL_DIR}" || {
        echo -e "${RED}Error: Installation failed for $ARCH${NC}" >&2; exit 1
    }

    echo -e "${GREEN}Packaging $ARCH build as .deb...${NC}"
    cd "$WORK_DIR" || { echo -e "${RED}Error: Failed to cd to $WORK_DIR${NC}" >&2; exit 1; }
    apt remove -y "mesa-vulkan-drivers:${ARCH}" 2>/dev/null || true
    apt download "mesa-vulkan-drivers:${ARCH}" || {
        echo -e "${RED}Error: Failed to download mesa-vulkan-drivers:${ARCH}${NC}" >&2; exit 1
    }

    mkdir -p "$INSTALL_DIR/DEBIAN" || { echo -e "${RED}Error: Failed to create DEBIAN dir${NC}" >&2; exit 1; }

    local DEB_FILE
    DEB_FILE=$(ls mesa-vulkan-drivers_*_"${ARCH}".deb)
    dpkg-deb -e "$DEB_FILE" "$INSTALL_DIR/DEBIAN/" || {
        echo -e "${RED}Error: Failed to extract metadata from $DEB_FILE${NC}" >&2; exit 1
    }

    sed -i "3s/.*/Version: ${MESA_VERSION}-${BUILD_DATE}/g" "$INSTALL_DIR/DEBIAN/control" || {
        echo -e "${RED}Error: Failed to modify control file${NC}" >&2; exit 1
    }

    rm -f "$DEB_FILE"
    rm -f "$INSTALL_DIR/DEBIAN/md5sums" "$INSTALL_DIR/DEBIAN/triggers"
    rm -rf "$INSTALL_DIR/usr/share/drirc.d"

    find "$INSTALL_DIR/usr" -maxdepth 1 -type d \
        -not -name "lib" -not -name "share" -not -name "usr" \
        -exec rm -rf {} \;

    # Note the grouping parentheses: without them, -type f -o -type l has lower
    # precedence than the rest of the expression, so -delete would only apply to
    # symlinks and regular files would just be printed. The braces fix that.
    find "$INSTALL_DIR/usr/$LIBDIR" \( -type f -o -type l \) \
        -not -name "libvulkan_freedreno.so" -delete

    find "$INSTALL_DIR/usr/share" \( -type f -o -type l \) \
        -not -name "$ICD_JSON" -delete

    find "$INSTALL_DIR/usr" -type d -empty -delete

    dpkg-deb --build --root-owner-group "$INSTALL_DIR" "$OUTPUT_FILE" || {
        echo -e "${RED}Error: Failed to create $OUTPUT_FILE${NC}" >&2; exit 1
    }
}

# ---------------------------------------------------------------------------
# Generate cross files, then build the requested arch(es).
# ---------------------------------------------------------------------------
case "$ARCH_FILTER" in
    arm64)
        generate_cross_file arm64
        echo -e "${GREEN}Starting ARM64 build...${NC}"
        build_mesa arm64
        ;;
    armhf)
        generate_cross_file armhf
        echo -e "${GREEN}Starting ARMHF build...${NC}"
        build_mesa armhf
        ;;
    all)
        generate_cross_file arm64
        generate_cross_file armhf
        echo -e "${GREEN}Starting ARM64 build...${NC}"
        build_mesa arm64
        echo -e "${GREEN}Starting ARMHF build...${NC}"
        build_mesa armhf
        ;;
    *)
        echo -e "${RED}Error: Unknown ARCH_FILTER '$ARCH_FILTER'. Use arm64, armhf, or all.${NC}" >&2
        exit 1
        ;;
esac

echo -e "${GREEN}Mesa $MESA_VERSION cross-compiled successfully!${NC}"
echo -e "${GREEN}Output files:${NC}"

if [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "arm64" ]; then
    echo -e "  - $OUTPUT_DIR/mesa-vulkan-kgsl_$MESA_VERSION-$BUILD_DATE-arm64.deb"
fi
if [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "armhf" ]; then
    echo -e "  - $OUTPUT_DIR/mesa-vulkan-kgsl_$MESA_VERSION-$BUILD_DATE-armhf.deb"
fi
