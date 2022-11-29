# Copyright (C) 2018-2022 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

cmake_policy(SET CMP0054 NEW)

# TODO: fix it
set_temp_directory(TEMP "${CMAKE_SOURCE_DIR}")

if(ENABLE_SAME_BRANCH_FOR_MODELS)
    branchName(MODELS_BRANCH)
else()
    set(MODELS_BRANCH "master")
endif()

if(ENABLE_DATA)
    add_models_repo(${ENABLE_DATA} "data:https://github.com/openvinotoolkit/testdata.git")
    set(MODELS_PATH "${TEMP}/models/src/data")
    set(DATA_PATH "${MODELS_PATH}")
endif()

message(STATUS "MODELS_PATH=" ${MODELS_PATH})

fetch_models_and_validation_set()

get_linux_name(LINUX_OS_NAME)

if(CMAKE_CROSSCOMPILING AND CMAKE_HOST_SYSTEM_NAME MATCHES Linux AND CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "amd64.*|x86_64.*|AMD64.*")
    set(protoc_version "3.18.2")

    RESOLVE_DEPENDENCY(SYSTEM_PROTOC_ROOT
        ARCHIVE_LIN "protoc-${protoc_version}-linux-x86_64.tar.gz"
        TARGET_PATH "${TEMP}/protoc-${protoc_version}-linux-x86_64"
        SHA256 "42fde2b6044c1f74c7e86d4e03b43aac87128ddf57ac6ed8c4eab7a1e21bbf21"
    )
    debug_message(STATUS "host protoc-${protoc_version} root path = " ${SYSTEM_PROTOC_ROOT})

    reset_deps_cache(SYSTEM_PROTOC)

    find_host_program(
        SYSTEM_PROTOC
        NAMES protoc
        PATHS "${SYSTEM_PROTOC_ROOT}/bin"
        NO_DEFAULT_PATH)
    if(NOT SYSTEM_PROTOC)
        message(FATAL_ERROR "[ONNX IMPORTER] Missing host protoc binary")
    endif()

    update_deps_cache(SYSTEM_PROTOC "${SYSTEM_PROTOC}" "Path to host protoc for ONNX Importer")
endif()

if(ENABLE_INTEL_MYRIAD)
    include(${OpenVINO_SOURCE_DIR}/src/plugins/intel_myriad/myriad_dependencies.cmake)
endif()

## Intel OMP package
if(THREADING STREQUAL "OMP")
    reset_deps_cache(OMP)
    if(WIN32 AND X86_64)
        RESOLVE_DEPENDENCY(OMP
                ARCHIVE_WIN "iomp.zip"
                TARGET_PATH "${TEMP}/omp"
                ENVIRONMENT "OMP"
                VERSION_REGEX ".*_([a-z]*_([a-z0-9]+\\.)*[0-9]+).*"
                SHA256 "62c68646747fb10f19b53217cb04a1e10ff93606f992e6b35eb8c31187c68fbf")
    elseif(LINUX AND X86_64)
        RESOLVE_DEPENDENCY(OMP
                ARCHIVE_LIN "iomp.tgz"
                TARGET_PATH "${TEMP}/omp"
                ENVIRONMENT "OMP"
                VERSION_REGEX ".*_([a-z]*_([a-z0-9]+\\.)*[0-9]+).*"
                SHA256 "7832b16d82513ee880d97c27c7626f9525ebd678decf6a8fe6c38550f73227d9")
    elseif(APPLE AND X86_64)
        RESOLVE_DEPENDENCY(OMP
                ARCHIVE_MAC "iomp_20190130_mac.tgz"
                TARGET_PATH "${TEMP}/omp"
                ENVIRONMENT "OMP"
                VERSION_REGEX ".*_([a-z]*_([a-z0-9]+\\.)*[0-9]+).*"
                SHA256 "591ea4a7e08bbe0062648916f42bded71d24c27f00af30a8f31a29b5878ea0cc")
    else()
        message(FATAL_ERROR "Intel OMP is not available on current platform")
    endif()
    update_deps_cache(OMP "${OMP}" "Path to OMP root folder")
    debug_message(STATUS "intel_omp=" ${OMP})

    ie_cpack_add_component(omp REQUIRED)
    file(GLOB_RECURSE source_list "${OMP}/*${CMAKE_SHARED_LIBRARY_SUFFIX}*")
    install(FILES ${source_list}
            DESTINATION "runtime/3rdparty/omp/lib"
            COMPONENT omp)
endif()

## TBB package
unset(_ov_download_tbb_done CACHE)

#
# The function downloads prebuilt TBB package
# NOTE: the function should be used if system TBB is not found
# or ENABLE_SYSTEM_TBB is OFF
#
function(ov_download_tbb)
    if(_ov_download_tbb_done OR NOT THREADING MATCHES "^(TBB|TBB_AUTO)$")
        return()
    endif()
    set(_ov_download_tbb_done ON CACHE BOOL "Whether prebuilt TBB is already downloaded")

    reset_deps_cache(TBBROOT TBB_DIR)

    if(DEFINED ENV{THIRDPARTY_SERVER_PATH})
        set(IE_PATH_TO_DEPS "$ENV{THIRDPARTY_SERVER_PATH}")
    elseif(DEFINED THIRDPARTY_SERVER_PATH)
        set(IE_PATH_TO_DEPS "${THIRDPARTY_SERVER_PATH}")
    endif()

    if(WIN32 AND X86_64)
        # TODO: add target_path to be platform specific as well, to avoid following if
        RESOLVE_DEPENDENCY(TBB
                ARCHIVE_WIN "tbb2020_617e9a71_win.zip"
                TARGET_PATH "${TEMP}/tbb"
                ENVIRONMENT "TBBROOT"
                SHA256 "01cac3cc48705bd52b83a6e1fa1ed95c708928be76160f5b9c5c37f954d56df4"
                USE_NEW_LOCATION TRUE)
    elseif(ANDROID)  # Should be before LINUX due LINUX is detected as well
        RESOLVE_DEPENDENCY(TBB
                ARCHIVE_ANDROID "tbb2020_20200404_android.tgz"
                TARGET_PATH "${TEMP}/tbb"
                ENVIRONMENT "TBBROOT"
                SHA256 "f42d084224cc2d643314bd483ad180b081774608844000f132859fca3e9bf0ce")
    elseif(LINUX AND X86_64)
        RESOLVE_DEPENDENCY(TBB
                ARCHIVE_LIN "tbb2020_20200415_lin_strip.tgz"
                TARGET_PATH "${TEMP}/tbb"
                ENVIRONMENT "TBBROOT"
                SHA256 "95b2f3b0b70c7376a0c7de351a355c2c514b42c4966e77e3e34271a599501008")
    elseif(LINUX AND AARCH64)
        RESOLVE_DEPENDENCY(TBB
                ARCHIVE_LIN "keembay/tbb2020_38404_kmb_lic.tgz"
                TARGET_PATH "${TEMP}/tbb_yocto"
                ENVIRONMENT "TBBROOT"
                SHA256 "321261ff2eda6d4568a473cb883262bce77a93dac599f7bd65d2918bdee4d75b")
    elseif(APPLE AND X86_64)
        RESOLVE_DEPENDENCY(TBB
                ARCHIVE_MAC "tbb2020_20200404_mac.tgz"
                TARGET_PATH "${TEMP}/tbb"
                ENVIRONMENT "TBBROOT"
                SHA256 "ad9cf52e657660058aa6c6844914bc0fc66241fec89a392d8b79a7ff69c3c7f6")
    else()
        message(FATAL_ERROR "TBB is not available on current platform")
    endif()

    update_deps_cache(TBBROOT "${TBB}" "Path to TBB root folder")
    if(EXISTS "${TBBROOT}/lib/cmake/TBB/TBBConfig.cmake")
        # oneTBB case
        update_deps_cache(TBB_DIR "${TBBROOT}/lib/cmake/TBB" "Path to TBB cmake folder")
    elseif(EXISTS "${TBBROOT}/lib/cmake/tbb/TBBConfig.cmake")
        # oneTBB release package version less than 2021.6.0
        update_deps_cache(TBB_DIR "${TBBROOT}/lib/cmake/tbb" "Path to TBB cmake folder")
    elseif(EXISTS "${TBBROOT}/lib64/cmake/TBB/TBBConfig.cmake")
        # 64-bits oneTBB case
        update_deps_cache(TBB_DIR "${TBBROOT}/lib64/cmake/TBB" "Path to TBB cmake folder")
    elseif(EXISTS "${TBBROOT}/cmake/TBBConfig.cmake")
        # custom downloaded or user provided TBB
        update_deps_cache(TBB_DIR "${TBBROOT}/cmake" "Path to TBB cmake folder")
    else()
        message(WARNING "Failed to find TBBConfig.cmake in ${TBBROOT} tree. Custom TBBConfig.cmake will be used")
    endif()

    debug_message(STATUS "tbb=" ${TBB})
    debug_message(STATUS "tbb_dir=" ${TBB_DIR})
    debug_message(STATUS "tbbroot=" ${TBBROOT})

    set(TBB "${TBB}" PARENT_SCOPE)
endfunction()

## TBBBind_2_5 package
unset(_ov_download_tbbbind_2_5_done CACHE)

#
# The function downloads static prebuilt TBBBind_2_5 package
# NOTE: the function should be called only we have TBB with version less 2021
#
function(ov_download_tbbbind_2_5)
    if(_ov_download_tbbbind_2_5_done OR NOT ENABLE_TBBBIND_2_5)
        return()
    endif()
    set(_ov_download_tbbbind_2_5_done ON CACHE BOOL "Whether prebuilt TBBBind_2_5 is already downloaded")

    reset_deps_cache(TBBBIND_2_5_DIR)

    if(DEFINED ENV{THIRDPARTY_SERVER_PATH})
        set(IE_PATH_TO_DEPS "$ENV{THIRDPARTY_SERVER_PATH}")
    elseif(DEFINED THIRDPARTY_SERVER_PATH)
        set(IE_PATH_TO_DEPS "${THIRDPARTY_SERVER_PATH}")
    endif()

    if(WIN32 AND X86_64)
        RESOLVE_DEPENDENCY(TBBBIND_2_5
                ARCHIVE_WIN "tbbbind_2_5_static_win_v1.zip"
                TARGET_PATH "${TEMP}/tbbbind_2_5"
                ENVIRONMENT "TBBBIND_2_5_ROOT"
                SHA256 "a67afeea8cf194f97968c800dab5b5459972908295242e282045d6b8953573c1")
    elseif(ANDROID)
        # don't have TBBBIND_2_5
    elseif(LINUX AND X86_64)
        RESOLVE_DEPENDENCY(TBBBIND_2_5
                ARCHIVE_LIN "tbbbind_2_5_static_lin_v2.tgz"
                TARGET_PATH "${TEMP}/tbbbind_2_5"
                ENVIRONMENT "TBBBIND_2_5_ROOT"
                SHA256 "865e7894c58402233caf0d1b288056e0e6ab2bf7c9d00c9dc60561c484bc90f4")
    else()
        message(WARNING "prebuilt TBBBIND_2_5 is not available.
Build oneTBB from sources and set TBBROOT environment var before OpenVINO cmake configure")
    endif()

    update_deps_cache(TBBBIND_2_5_DIR "${TBBBIND_2_5}/cmake" "Path to TBBBIND_2_5 cmake folder")

    set(TBBBIND_2_5 "${TBBBIND_2_5}" PARENT_SCOPE)
endfunction()

## OpenCV
if(ENABLE_OPENCV)
    reset_deps_cache(OpenCV_DIR)

    set(OPENCV_VERSION "4.5.2")
    set(OPENCV_BUILD "076")
    set(OPENCV_BUILD_YOCTO "772")

    if(AARCH64)
        if(DEFINED ENV{THIRDPARTY_SERVER_PATH})
            set(IE_PATH_TO_DEPS "$ENV{THIRDPARTY_SERVER_PATH}")
        elseif(DEFINED THIRDPARTY_SERVER_PATH)
            set(IE_PATH_TO_DEPS "${THIRDPARTY_SERVER_PATH}")
        else()
            message(WARNING "OpenCV is not found!")
        endif()

        if(DEFINED IE_PATH_TO_DEPS)
            set(OPENCV_SUFFIX "yocto_kmb")
            set(OPENCV_BUILD "${OPENCV_BUILD_YOCTO}")

            RESOLVE_DEPENDENCY(OPENCV
                    ARCHIVE_LIN "opencv/opencv_${OPENCV_VERSION}-${OPENCV_BUILD}_${OPENCV_SUFFIX}.txz"
                    TARGET_PATH "${TEMP}/opencv_${OPENCV_VERSION}_${OPENCV_SUFFIX}/opencv"
                    ENVIRONMENT "OpenCV_DIR"
                    VERSION_REGEX ".*_([0-9]+.[0-9]+.[0-9]+).*"
                    SHA256 "23c250796ad5fc9db810e1680ccdb32c45dc0e50cace5e0f02b30faf652fe343")

            unset(IE_PATH_TO_DEPS)
        endif()
    else()
        if(WIN32 AND X86_64)
            RESOLVE_DEPENDENCY(OPENCV
                    ARCHIVE_WIN "opencv/opencv_${OPENCV_VERSION}-${OPENCV_BUILD}.txz"
                    TARGET_PATH "${TEMP}/opencv_${OPENCV_VERSION}/opencv"
                    ENVIRONMENT "OpenCV_DIR"
                    VERSION_REGEX ".*_([0-9]+.[0-9]+.[0-9]+).*"
                    SHA256 "a14f872e6b63b6ac12c7ff47fa49e578d14c14433b57f5d85ab5dd48a079938c")
        elseif(APPLE AND X86_64)
            RESOLVE_DEPENDENCY(OPENCV
                    ARCHIVE_MAC "opencv/opencv_${OPENCV_VERSION}-${OPENCV_BUILD}_osx.txz"
                    TARGET_PATH "${TEMP}/opencv_${OPENCV_VERSION}_osx/opencv"
                    ENVIRONMENT "OpenCV_DIR"
                    VERSION_REGEX ".*_([0-9]+.[0-9]+.[0-9]+).*"
                    SHA256 "3e162f96e86cba8836618134831d9cf76df0438778b3e27e261dedad9254c514")
        elseif(LINUX)
            if(AARCH64)
                set(OPENCV_SUFFIX "yocto_kmb")
                set(OPENCV_BUILD "${OPENCV_BUILD_YOCTO}")
            elseif(ARM)
                set(OPENCV_SUFFIX "debian9arm")
                set(OPENCV_HASH "4274f8c40b17215f4049096b524e4a330519f3e76813c5a3639b69c48633d34e")
            elseif((LINUX_OS_NAME STREQUAL "CentOS 7" OR
                     CMAKE_CXX_COMPILER_VERSION VERSION_LESS "4.9") AND X86_64)
                set(OPENCV_SUFFIX "centos7")
                set(OPENCV_HASH "5fa76985c84fe7c64531682ef0b272510c51ac0d0565622514edf1c88b33404a")
            elseif(LINUX_OS_NAME MATCHES "CentOS 8" AND X86_64)
                set(OPENCV_SUFFIX "centos8")
                set(OPENCV_HASH "db087dfd412eedb8161636ec083ada85ff278109948d1d62a06b0f52e1f04202")
            elseif(LINUX_OS_NAME STREQUAL "Ubuntu 16.04" AND X86_64)
                set(OPENCV_SUFFIX "ubuntu16")
                set(OPENCV_HASH "cd46831b4d8d1c0891d8d22ff5b2670d0a465a8a8285243059659a50ceeae2c3")
            elseif(LINUX_OS_NAME STREQUAL "Ubuntu 18.04" AND X86_64)
                set(OPENCV_SUFFIX "ubuntu18")
                set(OPENCV_HASH "db087dfd412eedb8161636ec083ada85ff278109948d1d62a06b0f52e1f04202")
            elseif((LINUX_OS_NAME STREQUAL "Ubuntu 20.04" OR LINUX_OS_NAME STREQUAL "LinuxMint 20.1") AND X86_64)
                set(OPENCV_SUFFIX "ubuntu20")
                set(OPENCV_HASH "2fe7bbc40e1186eb8d099822038cae2821abf617ac7a16fadf98f377c723e268")
            elseif(NOT DEFINED OpenCV_DIR AND NOT DEFINED ENV{OpenCV_DIR})
                message(FATAL_ERROR "OpenCV is not available on current platform (${LINUX_OS_NAME})")
            endif()
            RESOLVE_DEPENDENCY(OPENCV
                    ARCHIVE_LIN "opencv/opencv_${OPENCV_VERSION}-${OPENCV_BUILD}_${OPENCV_SUFFIX}.txz"
                    TARGET_PATH "${TEMP}/opencv_${OPENCV_VERSION}_${OPENCV_SUFFIX}/opencv"
                    ENVIRONMENT "OpenCV_DIR"
                    VERSION_REGEX ".*_([0-9]+.[0-9]+.[0-9]+).*"
                    SHA256 ${OPENCV_HASH})
        endif()
    endif()

    if(ANDROID)
        set(ocv_cmake_path "${OPENCV}/sdk/native/jni/")
    else()
        set(ocv_cmake_path "${OPENCV}/cmake")
    endif()

    update_deps_cache(OpenCV_DIR "${ocv_cmake_path}" "Path to OpenCV package folder")
    debug_message(STATUS "opencv=" ${OPENCV})
else()
    reset_deps_cache(OpenCV_DIR)
endif()

if(ENABLE_INTEL_GNA)
    reset_deps_cache(
            GNA_EXT_DIR
            GNA_PLATFORM_DIR
            GNA_KERNEL_LIB_NAME
            GNA_LIBS_LIST
            GNA_LIB_DIR
            libGNA_INCLUDE_DIRS
            libGNA_LIBRARIES_BASE_PATH)
    set(GNA_VERSION "03.05.00.1472.1")
    set(GNA_HASH "2175cf3c39d3f8e5eb09bb6602d64b2c944ee8249bb927567d019353cb7165f0")

    set(FILES_TO_EXTRACT_LIST gna_${GNA_VERSION}/include)
    if(WIN32)
        LIST(APPEND FILES_TO_EXTRACT_LIST gna_${GNA_VERSION}/win64)
    else()
        LIST(APPEND FILES_TO_EXTRACT_LIST gna_${GNA_VERSION}/linux)
    endif()

    RESOLVE_DEPENDENCY(GNA_EXT_DIR
            ARCHIVE_UNIFIED "gna/gna_${GNA_VERSION}.zip"
            TARGET_PATH "${TEMP}/gna_${GNA_VERSION}"
            VERSION_REGEX ".*_([0-9]+.[0-9]+.[0-9]+.[0-9]+).*"
            FILES_TO_EXTRACT FILES_TO_EXTRACT_LIST
            SHA256 ${GNA_HASH}
            USE_NEW_LOCATION TRUE)
    update_deps_cache(GNA_EXT_DIR "${GNA_EXT_DIR}" "Path to GNA root folder")
    debug_message(STATUS "gna=" ${GNA_EXT_DIR})

    if (WIN32)
        set(GNA_PLATFORM_DIR win64 CACHE STRING "" FORCE)
    elseif (UNIX)
        set(GNA_PLATFORM_DIR linux CACHE STRING "" FORCE)
    else ()
        message(FATAL_ERROR "GNA not supported on this platform, only linux, and windows")
    endif ()

    set(GNA_LIB_DIR x64 CACHE STRING "" FORCE)
    set(GNA_PATH ${GNA_EXT_DIR}/${GNA_PLATFORM_DIR}/${GNA_LIB_DIR} CACHE STRING "" FORCE)

    if (WIN32)
        message(STATUS "Renaming gna.dll to gna_preproc.dll")
        execute_process(COMMAND ${CMAKE_COMMAND} -E rename gna.dll gna_preproc.dll
          WORKING_DIRECTORY ${GNA_PATH}
          RESULT_VARIABLE rv
          ERROR_VARIABLE err)

        message(STATUS "rename rv: ${rv}")
        message(STATUS "rename err: ${err}")

        string(REPLACE "lib.exe" "dumpbin.exe" OBJDUMP ${CMAKE_AR})
        message(STATUS "OBJDUMP: ${OBJDUMP}")

        execute_process(COMMAND ${OBJDUMP} /EXPORTS gna_preproc.dll /OUT:gna_preproc.dll.exports
          WORKING_DIRECTORY ${GNA_PATH}
          RESULT_VARIABLE rv
          ERROR_VARIABLE err)

        message(STATUS "dumpin rv: ${rv}")
        message(STATUS "dumpbin err: ${err}")

        set(DEF_FILE ${GNA_PATH}/gna_preproc.def)
        FILE(WRITE ${DEF_FILE} "LIBRARY gna_preproc\n")
        FILE(APPEND ${DEF_FILE} "EXPORTS\n")

        execute_process(COMMAND powershell -Command "(gc gna_preproc.dll.exports) -match \'\\s*(\\d+)\\s+[A-Z0-9]+\\s+[A-Z0-9]{8}\\s+([^ ]+(?: = [^ ]+)?)\\s*\' -replace \'\\s*(\\d+)\\s+[A-Z0-9]+\\s+[A-Z0-9]{8}\\s+([^ ]+(?: = [^ ]+)?)\\s*\', \'    $2   @$1\' | Out-File -encoding ASCII ${DEF_FILE} -append"
          WORKING_DIRECTORY ${GNA_PATH}
          RESULT_VARIABLE rv
          ERROR_VARIABLE err)

        message(STATUS "regexp rv: ${rv}")
        message(STATUS "regexp err: ${err}")

        execute_process(COMMAND ${CMAKE_AR} /MACHINE:x64 /def:${DEF_FILE}
          WORKING_DIRECTORY ${GNA_PATH}
          RESULT_VARIABLE rv
          ERROR_VARIABLE err)

        message(STATUS "lib rv: ${rv}")
        message(STATUS "lib err: ${err}")

        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f gna.lib gna_preproc.dll.exports
          WORKING_DIRECTORY ${GNA_PATH}
          RESULT_VARIABLE rv
          ERROR_VARIABLE err)

    endif ()

    if(NOT BUILD_SHARED_LIBS)
        list(APPEND PATH_VARS "GNA_PATH")
    endif()
endif()
