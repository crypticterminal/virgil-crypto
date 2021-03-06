#!/bin/bash
#
# Copyright (C) 2015-2018 Virgil Security Inc.
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     (1) Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#     (2) Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#
#     (3) Neither the name of the copyright holder nor the names of its
#     contributors may be used to endorse or promote products derived from
#     this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>
#

# Abort if something went wrong
set -e

# Color constants
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_ORANGE='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_YELLOW='\033[1;33m'
COLOR_WHITE='\033[1;37m'
COLOR_RESET='\033[0m'

# Util functions
function show_usage {
    if [ ! -z "$1" ]; then
        echo -e "${COLOR_RED}[ERROR] $1${COLOR_RESET}"
    fi
    echo -e "This script helps to build crypto library for variety of languages and platforms."
    echo -e "Common reuirements: CMake 3.10, Python, PyYaml, SWIG 3.0.12."
    echo -e "${COLOR_BLUE}Usage: ${BASH_SOURCE[0]} [--target=<target>] [--feature=<feature>] [--src=<src_dir>] [--build=<build_dir>] [--install=<install_dir>]${COLOR_RESET}"
    echo -e "  - <target> - (default = cpp) target to build which contains two parts <name>[-<version>], where <name>:"
    echo -e "      * cpp              - build C++ library;"
    echo -e "      * macos            - build framework for Apple macOSX, requirements: OS X, Xcode;"
    echo -e "      * ios              - build framework for Apple iOS, requirements: OS X, Xcode;"
    echo -e "      * watchos          - build framework for Apple WatchOS, requirements: OS X, Xcode;"
    echo -e "      * tvos             - build framework for Apple TVOS, requirements: OS X, Xcode;"
    echo -e "      * php              - build PHP library, requirements: php-dev;"
    echo -e "      * python           - build Python library;"
    echo -e "      * ruby             - build Ruby library;"
    echo -e "      * java             - build Java library, requirements: \$JAVA_HOME;"
    echo -e "      * java_android     - build Java library under Android platform, requirements: \$ANDROID_NDK;"
    echo -e "      * net              - build .NET library, requirements: .NET or Mono;"
    echo -e "      * net_macos        - build .NET library under Apple macOSX platform, requirements: Mono, OS X, Xcode;"
    echo -e "      * net_ios          - build .NET library under Apple iOS platform, requirements: Mono, OS X, Xcode;"
    echo -e "      * net_applewatchos - build .NET library under WatchOS platform, requirements: Mono, OS X, Xcode;"
    echo -e "      * net_appletvos    - build .NET library under TVOS platform, requirements: Mono, OS X, Xcode;"
    echo -e "      * net_android      - build .NET library under Android platform, requirements: Mono, \$ANDROID_NDK;"
    echo -e "      * asmjs            - build AsmJS library, requirements: \$EMSDK_HOME;"
    echo -e "      * webasm           - build WebAssembly library, requirements: \$EMSDK_HOME;"
    echo -e "      * nodejs           - build NodeJS module;"
    echo -e "      * go               - build Golang library."
    echo -e ""
    echo -e "  - <feature> - available features:"
    echo -e "      * pythia           - ask to enable feature Pythia. Some targets enable this feature by default."
    echo -e ""
    echo -e "  - <src_dir>     - (default = .) path to the directory where root CMakeLists.txt file is located."
    echo -e "  - <build_dir>   - (default = build/<target>) path to the directory where temp files will be stored."
    echo -e "  - <install_dir> - (default = install/<target>) path to the directory where library files will be installed".

    exit ${2:0}
}

function show_info {
    echo -e "${COLOR_GREEN}[INFO] $@${COLOR_RESET}"
}

function show_error {
    echo -e "${COLOR_RED}[ERROR] $@${COLOR_RESET}"
    exit 1
}

function abspath() {
  (
    if [ -d "$1" ]; then
        cd "$1" && pwd -P
    else
        echo "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
    fi
  )
}

function make_fat_framework {
    # Define name of the fat library
    if [ ! -z "$1" ]; then
        FRAMEWORK_NAME="$1"
    else
        show_error "Error. Framework name is not defined."
    fi

    # Define install directory
    if [ ! -z "$2" ]; then
        INDIR="$2"
    else
        show_error "Error. Input directory is not defined."
    fi

    # Define output directory
    if [ ! -z "$3" ]; then
        OUTDIR="$3"
    else
        show_error "Error. Output directory is not defined."
    fi

    # Create output dir
    mkdir -p "$OUTDIR"

    # Remove output framework if exists
    OUTPUT_FRAMEWORK="${OUTDIR}/${FRAMEWORK_NAME}.framework"
    rm -fr "${OUTPUT_FRAMEWORK}"

    # Find all frameworks with given name
    FRAMEWORKS=$(find "${INDIR}" -name "${FRAMEWORK_NAME}.framework" | tr '\n' ' ')

    if [ -z "${FRAMEWORKS}" ]; then
        show_error "Error. Frameworks named'${FRAMEWORK_NAME}.framework'" \
                "are not found within directory: ${INDIR}."
    fi

    # Get frameworks binary
    FRAMEWORKS_BIN=""
    for framework in ${FRAMEWORKS}; do
        FRAMEWORKS_BIN+=$(find "${framework}" -type f -perm +111 -name "${FRAMEWORK_NAME}")
        FRAMEWORKS_BIN+=" "
    done

    # Copy first framework to the output and remove it's binary
    rsync --recursive --links "$(echo "${FRAMEWORKS}" | awk '{print $1}')/" "${OUTPUT_FRAMEWORK}"
    OUTPUT_FRAMEWORK_BIN=$(find "${OUTPUT_FRAMEWORK}" -type f -perm +111 -name "${FRAMEWORK_NAME}")
    rm "${OUTPUT_FRAMEWORK_BIN}"

    # Merge found framework binaries to the output framework
    lipo -create ${FRAMEWORKS_BIN} -o ${OUTPUT_FRAMEWORK_BIN}
}

function make_fat_library {
    # Define name of the fat library
    if [ ! -z "$1" ]; then
        LIB_FAT_NAME="$1"
    else
        show_error "Error. Bundle name is not defined."
    fi

    # Define install directory
    if [ ! -z "$2" ]; then
        INDIR="$2"
    else
        show_error "Error. Input directory is not defined."
    fi

    # Define working directory
    if [ ! -z "$3" ]; then
        OUTDIR="$3"
    else
        show_error "Error. Output directory is not defined."
    fi

    # Define wrapper name (optional)
    if [ ! -z "$4" ]; then
        WRAPPER_NAME="$4"
    fi

    LIBMBEDTLS="libmbedcrypto.a"
    LIBED25519="libed25519.a"
    LIBRELIC="librelic_s.a"
    LIBPYTHIA="libpythia.a"
    LIBVIRGIL="libvirgil_crypto.a"
    if [ ! -z "${WRAPPER_NAME}" ]; then
        LIBVIRGIL_WRAPPER="virgil_crypto_${WRAPPER_NAME}.a"
    fi

    # Create working dir
    mkdir -p "$OUTDIR"

    # Find all archs of library ARM mbedTLS
    LIBMBEDTLS_LIBS=$(find "${INDIR}" -name "${LIBMBEDTLS}" | tr '\n' ' ')

    # Find all archs of library ed25519
    LIBED25519_LIBS=$(find "${INDIR}" -name "${LIBED25519}" | tr '\n' ' ')

    # Find all archs of library relic
    LIBRELIC_LIBS=$(find "${INDIR}" -name "${LIBRELIC}" | tr '\n' ' ')

    # Find all archs of library pythia
    LIBPYTHIA_LIBS=$(find "${INDIR}" -name "${LIBPYTHIA}" | tr '\n' ' ')

    # Find all archs of library Virgil Crypto
    LIBVIRGIL_LIBS=$(find "${INDIR}" -name "${LIBVIRGIL}" | tr '\n' ' ')

    # Find all archs of library Virgil Crypto Wrapper
    if [ ! -z "${LIBVIRGIL_WRAPPER}" ]; then
        LIBVIRGIL_WRAPPER_LIBS=$(find "${INDIR}" -name "${LIBVIRGIL_WRAPPER}" | tr '\n' ' ')
    fi

    xcrun lipo -create ${LIBMBEDTLS_LIBS} -output "$OUTDIR/$LIBMBEDTLS"
    xcrun lipo -create ${LIBED25519_LIBS} -output "$OUTDIR/$LIBED25519"
    xcrun lipo -create ${LIBVIRGIL_LIBS} -output "$OUTDIR/$LIBVIRGIL"

    if [ ! -z "${LIBRELIC_LIBS}" ]; then
        LIBRELIC_FAT="$OUTDIR/$LIBRELIC"
        xcrun lipo -create ${LIBRELIC_LIBS} -output "${LIBRELIC_FAT}"
    fi

    if [ ! -z "${LIBPYTHIA_LIBS}" ]; then
        LIBPYTHIA_FAT="$OUTDIR/$LIBPYTHIA"
        xcrun lipo -create ${LIBPYTHIA_LIBS} -output "${LIBPYTHIA_FAT}"
    fi

    if [ ! -z "${LIBVIRGIL_WRAPPER_LIBS}" ]; then
        LIBVIRGIL_WRAPPER_FAT="$OUTDIR/$LIBVIRGIL_WRAPPER"
        xcrun lipo -create ${LIBVIRGIL_WRAPPER_LIBS} -output "$LIBVIRGIL_WRAPPER_FAT"
    fi

    # Merge several static libraries in one static library which will actually be framework
    # Note! Spaces in the filenames and paths are prohibited.
    # Note! Quoting the paths leads to failed build.
    xcrun libtool -static -o ${OUTDIR}/${LIB_FAT_NAME} \
            ${OUTDIR}/${LIBMBEDTLS} ${OUTDIR}/${LIBED25519} ${LIBRELIC_FAT} ${LIBPYTHIA_FAT} \
            ${OUTDIR}/${LIBVIRGIL} ${LIBVIRGIL_WRAPPER_FAT}

    # Cleanup
    rm -f "$OUTDIR/$LIBMBEDTLS"
    rm -f "$OUTDIR/$LIBED25519"
    rm -f "$OUTDIR/$LIBVIRGIL"

    if [ -f "${LIBPYTHIA_FAT}" ]; then
        rm -f "${LIBPYTHIA_FAT}"
    fi

    if [ -f "${LIBRELIC_FAT}" ]; then
        rm -f "${LIBRELIC_FAT}"
    fi

    if [ -f "${LIBVIRGIL_WRAPPER_FAT}" ]; then
        rm -f "${LIBVIRGIL_WRAPPER_FAT}"
    fi
}

# Parse arguments (https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash)
FEATURES=()
for arg in "$@"
do
case ${arg} in
    --target=*)
    TARGET="${arg#*=}"
    shift
    ;;
    --feature=*)
    FEATURES+=("${arg#*=}")
    shift
    ;;
    --src=*)
    SRC_DIR="${arg#*=}"
    shift
    ;;
    --build=*)
    BUILD_DIR="${arg#*=}"
    shift
    ;;
    --install=*)
    INSTALL_DIR="${arg#*=}"
    shift
    ;;
    -h|--help)
    show_usage
    ;;
    *)
    show_usage "Unknown argument '${arg}', or it's value is not defined."
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Define environment variables.
SCRIPT_DIR=$(dirname "$(abspath "${BASH_SOURCE[0]}")")
CURRENT_DIR=$(abspath .)

SYSTEM_KERNEL_RELEASE="$(uname -r)"
SYSTEM_KERNEL_RELEASE_PARTS=(${SYSTEM_KERNEL_RELEASE//-/ })
SYSTEM_KERNEL_RELEASE_PARTS=(${SYSTEM_KERNEL_RELEASE_PARTS[0]//./ })
SYSTEM_KERNEL_RELEASE_VERSION="${SYSTEM_KERNEL_RELEASE_PARTS[0]}.${SYSTEM_KERNEL_RELEASE_PARTS[1]}"

SYSTEM_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "${SYSTEM_NAME}" == "linux" ]; then
    SYSTEM_KERNEL_RELEASE_VERSION=""
fi

if [ -f "${SCRIPT_DIR}/env.sh" ]; then
    show_info "Setting up additional build environment"
    source "${SCRIPT_DIR}/env.sh"
fi

# Check arguments
if [ -z "$TARGET" ]; then
    TARGET="cpp"
fi
show_info "<target> : ${TARGET}"

target_arr=(${TARGET//-/ })
TARGET_NAME="${target_arr[0]}"
TARGET_VERSION="${target_arr[1]}"

show_info "<target_name> : ${TARGET_NAME}"
if [ ! -z "${TARGET_VERSION}" ]; then
    show_info "<target_version> : ${TARGET_VERSION}"
fi

if [ ! -z "${SRC_DIR}" ]; then
    SRC_DIR=$(abspath "${SRC_DIR}")
else
    SRC_DIR="${CURRENT_DIR}"
fi
show_info "<src_dir>: ${SRC_DIR}"

if [ ! -f "${SRC_DIR}/CMakeLists.txt" ]; then
    show_usage "Source directory does not contain root CMakeLists.txt file!" 1
fi

if [ ! -z "${BUILD_DIR}" ]; then
    mkdir -p "${BUILD_DIR}"
    BUILD_DIR=$(abspath "${BUILD_DIR}")
else
    BUILD_DIR="${CURRENT_DIR}/build/${TARGET_NAME}/${TARGET_VERSION}"
    mkdir -p "${BUILD_DIR}"
    BUILD_DIR=$(abspath "${BUILD_DIR}")
fi
show_info "<build_dir>: ${BUILD_DIR}"

if [ ! -z "${INSTALL_DIR}" ]; then
    mkdir -p "${INSTALL_DIR}"
    INSTALL_DIR=$(abspath "${INSTALL_DIR}")
else
    INSTALL_DIR="${CURRENT_DIR}/install/${TARGET_NAME}/${TARGET_VERSION}"
    mkdir -p "${INSTALL_DIR}"
    INSTALL_DIR=$(abspath "${INSTALL_DIR}")
fi
show_info "<install_dir>: ${INSTALL_DIR}"

if [ ! -z "${FEATURES[*]}" ]; then
    show_info "Requested features: ${FEATURES[*]}"
fi

# Define common build parameters
CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release"

# Expose low level API for all targets
CMAKE_ARGS+=" -DVIRGIL_CRYPTO_FEATURE_LOW_LEVEL_WRAP=ON"

if [[ ${TARGET_NAME} =~ ^(cpp|java|net|php|python|ruby|nodejs|go)$ ]]; then
    CMAKE_ARGS+=" -DPLATFORM_ARCH=$(uname -m)"
fi

if [ "${TARGET_NAME}" == "go" ]; then
    CMAKE_ARGS+=" -DINSTALL_CORE_LIBS=ON"
fi

if [ ! -z "${TARGET_VERSION}" ]; then
    CMAKE_ARGS+=" -DLANG_VERSION=${TARGET_VERSION}"
fi

if [ ! -z "${INSTALL_DIR}" ]; then
    CMAKE_ARGS+=" -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}"
fi

if [ ! -z "${FEATURES[*]}" ]; then
    for feature in ${FEATURES[*]}; do
        case ${feature} in
            pythia)
            feature_upper=$(echo "${feature}" | awk '{print toupper($0)}')
            CMAKE_ARGS+=" -DVIRGIL_CRYPTO_FEATURE_${feature_upper}=ON"
            ;;
            *)
            show_error "Undefined feature '${feature}'."
            ;;
        esac
    done
fi


# Go to the build directory
cd "${INSTALL_DIR}" && rm -fr ./*
cd "${BUILD_DIR}" && rm -fr ./*

# Build for native platforms
if [[ ${TARGET_NAME} =~ ^(cpp|java|net|php|python|ruby|nodejs|go)$ ]]; then
    CMAKE_ARGS+=" -DVIRGIL_CRYPTO_FEATURE_PYTHIA=ON"
    cmake ${CMAKE_ARGS} -DLANG=${TARGET_NAME} -DPLATFORM_VERSION=${SYSTEM_KERNEL_RELEASE_VERSION} "${SRC_DIR}"
    make -j8 install
fi

# Build framework for Apple iOS (with Pythia)
if [ "${TARGET_NAME}" == "ios" ]; then

    CMAKE_ARGS+=" -LANG=cpp"
    CMAKE_ARGS+=" -DINSTALL_CORE_HEADERS=NO"
    CMAKE_ARGS+=" -DINSTALL_EXT_LIBS=NO"
    CMAKE_ARGS+=" -DINSTALL_EXT_HEADERS=NO"
    CMAKE_ARGS+=" -DCMAKE_TOOLCHAIN_FILE='${SRC_DIR}/cmake/apple.cmake'"
    CMAKE_ARGS+=" -DVIRGIL_CRYPTO_FEATURE_PYTHIA=ON"

    # Build for device (Pythia is in a multi-thread mode!!!)
    rm -fr -- *
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=IOS \
                        -DVIRGIL_CRYPTO_FEATURE_PYTHIA_MT=ON \
                        -DINSTALL_LIB_DIR_NAME=lib/dev "${SRC_DIR}"
    make -j8 install

    # Build for i386 simulator (Pythia is in a single-thread mode!!!)
    rm -fr -- *
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=IOS_SIM32 \
                        -DVIRGIL_CRYPTO_FEATURE_PYTHIA_MT=OFF \
                        -DINSTALL_LIB_DIR_NAME=lib/sim32 "${SRC_DIR}"
    make -j8 install

    # Build for x86_64 simulator (Pythia is in a multi-thread mode!!!)
    rm -fr -- *
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=IOS_SIM64 \
                        -DVIRGIL_CRYPTO_FEATURE_PYTHIA_MT=ON \
                        -DINSTALL_LIB_DIR_NAME=lib/sim64 "${SRC_DIR}"
    make -j8 install

    make_fat_framework VSCCrypto "${INSTALL_DIR}" "${INSTALL_DIR}"

    rm -fr "${INSTALL_DIR:?}/include"
    rm -fr "${INSTALL_DIR:?}/lib"
fi

# Build framework for Apple tvOS, watchOS, macOS (without Pythia)
if [ "${TARGET_NAME}" == "tvos" ] || [ "${TARGET_NAME}" == "watchos" ] || [ "${TARGET_NAME}" == "macos" ]; then

    APPLE_PLATFORM_DEVICE=$(echo "${TARGET_NAME}" | awk '{print toupper($0)}')
    APPLE_PLATFORM_SIMULATOR="${APPLE_PLATFORM_DEVICE}_SIM"

    CMAKE_ARGS+=" -LANG=cpp"
    CMAKE_ARGS+=" -DINSTALL_CORE_HEADERS=NO"
    CMAKE_ARGS+=" -DINSTALL_EXT_LIBS=NO"
    CMAKE_ARGS+=" -DINSTALL_EXT_HEADERS=NO"
    CMAKE_ARGS+=" -DCMAKE_TOOLCHAIN_FILE='${SRC_DIR}/cmake/apple.cmake'"
    CMAKE_ARGS+=" -DVIRGIL_CRYPTO_FEATURE_PYTHIA=ON"

    # Build for device
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=${APPLE_PLATFORM_DEVICE} -DINSTALL_LIB_DIR_NAME=lib/dev "${SRC_DIR}"
    make -j8 install

    if [ "${TARGET_NAME}" != "macos" ]; then
        # Build for simulator

        if [ "${TARGET_NAME}" == "watchos" ]; then
            CMAKE_ARGS+=" -DVIRGIL_CRYPTO_FEATURE_PYTHIA_MT=OFF"
        fi

        rm -fr ./*
        cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=${APPLE_PLATFORM_SIMULATOR} -DINSTALL_LIB_DIR_NAME=lib/sim "${SRC_DIR}"
        make -j8 install
    fi

    make_fat_framework VSCCrypto "${INSTALL_DIR}" "${INSTALL_DIR}"

    rm -fr "${INSTALL_DIR:?}/include"
    rm -fr "${INSTALL_DIR:?}/lib"
fi

if [[ "${TARGET_NAME}" == *"android"* ]]; then
    if [ ! -d "$ANDROID_NDK" ]; then
        show_usage "Enviroment \$ANDROID_NDK is not defined!" 1
    fi

    if [ "${TARGET_NAME}" == "java_android" ]; then
        CMAKE_ARGS+=" -DLANG=java"
    elif [ "${TARGET_NAME}" == "net_android" ]; then
        CMAKE_ARGS+=" -DLANG=net"
    else
        show_usage "Unsupported target: ${TARGET_NAME}!"
    fi

    CMAKE_ARGS+=" -DVIRGIL_CRYPTO_FEATURE_PYTHIA=ON"

    function build_android() {
        # Build architecture: $1
        rm -fr ./*
        cmake ${CMAKE_ARGS} -DANDROID_ABI="$1" -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK}/build/cmake/android.toolchain.cmake" "${SRC_DIR}"
        make -j8 install
    }

    build_android x86
    build_android x86_64
    build_android armeabi-v7a
    build_android arm64-v8a
fi

# Build for Mono iOS (with Pyhia)
if [ "${TARGET_NAME}" == "net_ios" ]; then

    CMAKE_ARGS+=" -DLANG=net"
    CMAKE_ARGS+=" -DINSTALL_CORE_LIBS=ON"
    CMAKE_ARGS+=" -DINSTALL_CORE_HEADERS=OFF"
    CMAKE_ARGS+=" -DINSTALL_EXT_LIBS=ON"
    CMAKE_ARGS+=" -DINSTALL_EXT_HEADERS=OFF"
    CMAKE_ARGS+=" -DCMAKE_TOOLCHAIN_FILE='${SRC_DIR}/cmake/apple.cmake'"
    CMAKE_ARGS+=" -DVIRGIL_CRYPTO_FEATURE_PYTHIA=ON"

    # Build for device (Pythia is in a multi-thread mode!!!)
    rm -fr -- *
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=IOS \
                        -DVIRGIL_CRYPTO_FEATURE_PYTHIA_MT=ON \
                        -DINSTALL_LIB_DIR_NAME=lib/dev "${SRC_DIR}"
    make -j8 install

    # Build for i386 simulator (Pythia is in a single-thread mode!!!)
    rm -fr -- *
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=IOS_SIM32 \
                        -DVIRGIL_CRYPTO_FEATURE_PYTHIA_MT=OFF \
                        -DINSTALL_LIB_DIR_NAME=lib/sim32 "${SRC_DIR}"
    make -j8 install

    # Build for x86_64 simulator (Pythia is in a multi-thread mode!!!)
    rm -fr -- *
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=IOS_SIM64 \
                        -DVIRGIL_CRYPTO_FEATURE_PYTHIA_MT=ON \
                        -DINSTALL_LIB_DIR_NAME=lib/sim64 "${SRC_DIR}"
    make -j8 install

    # Create fat library
    make_fat_library libVirgilCryptoNet.a "${INSTALL_DIR}" "${INSTALL_DIR}/libs" "net"
    find "${INSTALL_DIR:?}" -name "*.dll" -exec cp -f {} "${INSTALL_DIR:?}/libs/" \;
    rm -fr "${INSTALL_DIR:?}/include"
    rm -fr "${INSTALL_DIR:?}/lib"
    mv "${INSTALL_DIR:?}/libs" "${INSTALL_DIR:?}/lib"
fi

# Build for Mono tvOS and Mono watchOS (without Pythia)
if [ "${TARGET_NAME}" == "net_tvos" ] || [ "${TARGET_NAME}" == "net_watchos" ]; then

    APPLE_PLATFORM_DEVICE=$(echo "${TARGET_NAME/net_/}" | awk '{print toupper($0)}')
    APPLE_PLATFORM_SIMULATOR="${APPLE_PLATFORM_DEVICE}_SIM"

    CMAKE_ARGS+=" -DLANG=net"
    CMAKE_ARGS+=" -DINSTALL_CORE_LIBS=ON"
    CMAKE_ARGS+=" -DINSTALL_CORE_HEADERS=OFF"
    CMAKE_ARGS+=" -DINSTALL_EXT_LIBS=ON"
    CMAKE_ARGS+=" -DINSTALL_EXT_HEADERS=OFF"
    CMAKE_ARGS+=" -DCMAKE_TOOLCHAIN_FILE='${SRC_DIR}/cmake/apple.cmake'"

    # Build for device
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=${APPLE_PLATFORM_DEVICE} -DINSTALL_LIB_DIR_NAME=lib/dev "${SRC_DIR}"
    make -j8 install

    # Build for simulator
    rm -fr ./*
    cmake ${CMAKE_ARGS} -DAPPLE_PLATFORM=${APPLE_PLATFORM_SIMULATOR} -DINSTALL_LIB_DIR_NAME=lib/sim "${SRC_DIR}"
    make -j8 install

    # Create fat library
    make_fat_library libVirgilCryptoNet.a "${INSTALL_DIR}" "${INSTALL_DIR}/libs" "net"
    find "${INSTALL_DIR:?}" -name "*.dll" -exec cp -f {} "${INSTALL_DIR:?}/libs/" \;
    rm -fr "${INSTALL_DIR:?}/include"
    rm -fr "${INSTALL_DIR:?}/lib"
    mv "${INSTALL_DIR:?}/libs" "${INSTALL_DIR:?}/lib"
fi

if [[ "${TARGET_NAME}" =~ (asmjs|webasm) ]]; then
    if [ ! -d "$EMSDK_HOME" ]; then
        show_usage "Enviroment \$EMSDK_HOME is not defined!" 1
    fi
    source "${EMSDK_HOME}/emsdk_env.sh"

    CMAKE_ARGS+=" -DVIRGIL_PACKAGE_NAME_FEATURES=ON"

    cmake ${CMAKE_ARGS} \
        -DLANG=${TARGET_NAME} \
        -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN/cmake/Modules/Platform/Emscripten.cmake" \
        -DCMAKE_CXX_FLAGS_RELEASE="-O3" \
        "${SRC_DIR}"
    make -j8 install
fi

if [ -z "$(ls -A ./)" ]; then
    show_usage "Given target '${TARGET_NAME}' is not supported." 1
fi

if [[ ${TARGET_NAME} =~ (ios|tvos|watchos|macos|android) ]]; then
    ARCH_NAME=$(cat "${BUILD_DIR}/lib_name.txt")
else
    ARCH_NAME=$(cat "${BUILD_DIR}/lib_name_full.txt")
fi

# Archive installed libraries and remove all except archive
mkdir -p "${INSTALL_DIR}/${ARCH_NAME}"
cd "${INSTALL_DIR}"
mv $(ls -A | grep -v ${ARCH_NAME}) "./${ARCH_NAME}"
cp -f "${SRC_DIR}/VERSION" "./${ARCH_NAME}"
tar -czvf "${ARCH_NAME}.tgz" -- *
find . ! -path . -type d -exec rm -fr {} +
