#!/bin/bash
#
# Copyright (C) 2015-2016 Virgil Security Inc.
#
# Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>
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

set -ev

# Configure CMake arguments
CMAKE_ARGS="-DLANG=${LANG} -DPLATFORM_ARCH=`uname -m`"
CMAKE_ARGS+=" -DLIB_LOW_LEVEL_API=${LIB_LOW_LEVEL_API}"
CMAKE_ARGS+=" -DCMAKE_INSTALL_PREFIX=${TRAVIS_BUILD_DIR}/install"
if [ "${LANG}" = "cpp" ]; then
    CMAKE_ARGS+=" -DLIB_FILE_IO=ON"
fi

# Run CMake
cd "${TRAVIS_BUILD_DIR}"
if [ -d "${BUILD_DIR_NAME}" ]; then
    rm -fr "${BUILD_DIR_NAME}"
fi

mkdir "${BUILD_DIR_NAME}"
cd "${BUILD_DIR_NAME}"

export PATH=$HOME/cmake/bin:$PATH
cmake --version

export PATH=$HOME/swig/bin:$PATH
swig -version

export PATH=$HOME/phpunit/bin:$PATH
phpunit --version

if [ "${PUBLISH_DOCS}" == "ON" ]; then
    export PATH=$HOME/doxygen/bin:$PATH
    doxygen --version
fi

cmake ${CMAKE_ARGS} ..
