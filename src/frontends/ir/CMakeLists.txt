# Copyright (C) 2018-2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

add_subdirectory(src)

if(ENABLE_TESTS)
    add_subdirectory(tests)
endif()

if(WIN32)
    target_link_options(openvino_ir_frontend PRIVATE /PDBALTPATH:$<TARGET_PDB_FILE_NAME:openvino_ir_frontend>)
endif()
