# Copyright (C) 2018-2022 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ov_add_frontend(NAME ir
                FILEDESCRIPTION "FrontEnd to load OpenVINO IR file format"
                LINK_LIBRARIES pugixml::static
                               # TODO: remove dependency below in CVS-69781
                               openvino::runtime::dev)

if(WIN32)
    set_property(TARGET openvino_ir_frontend APPEND_STRING PROPERTY LINK_FLAGS "/PDBSTRIPPED:openvino_ir_frontend_STRIPPED.pdb")
    target_link_options(openvino_ir_frontend PRIVATE /PDBALTPATH:$<TARGET_PDB_FILE_NAME:openvino_ir_frontend>)
endif()
