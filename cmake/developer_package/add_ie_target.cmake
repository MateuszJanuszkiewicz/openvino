# Copyright (C) 2018-2022 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

#[[
function to create CMake target and setup its options in a declarative style.
Example:
addIeTarget(
   NAME core_lib
   ADD_CPPLINT
   DEVELOPER_PACKAGE <component>
   TYPE <SHARED / STATIC / EXECUTABLE>
   ROOT ${CMAKE_CURRENT_SOURCE_DIR}
   ADDITIONAL_SOURCE_DIRS
        /some/additional/sources
   EXCLUDED_SOURCE_PATHS
        ${CMAKE_CURRENT_SOURCE_DIR}/unnecessary_sources/
   INCLUDES
        ${SDL_INCLUDES}
        /some/specific/path
   LINK_LIBRARIES
        link_dependencies
   DEPENDENCIES
        dependencies
        ie::important_plugin
   OBJECT_FILES
        object libraries
)
#]]
function(addIeTarget)
    set(options
        ADD_CPPLINT                   # Enables code style checks for the target
        ADD_CLANG_FORMAT              # Enables code style checks for the target
        )
    set(oneValueRequiredArgs
        TYPE # type of target, SHARED|STATIC|EXECUTABLE. SHARED and STATIC correspond to add_library, EXECUTABLE to add_executable
        NAME # name of target
        ROOT # root directory to be used for recursive search of source files
        )
    set(oneValueOptionalArgs
        DEVELOPER_PACKAGE             # Enables exporting of the target through the developer package
        )
    set(multiValueArgs
        INCLUDES                      # Extra include directories
        LINK_LIBRARIES                # Link libraries (in form of target name or file name)
        DEPENDENCIES                  # compile order dependencies (no link implied)
        DEFINES                       # extra preprocessor definitions
        ADDITIONAL_SOURCE_DIRS        # list of directories which will be used to recursive search of source files in addition to ROOT
        OBJECT_FILES                  # list of object files to be additionally built into the target
        EXCLUDED_SOURCE_PATHS         # list of paths excluded from the global recursive search of source files
        LINK_LIBRARIES_WHOLE_ARCHIVE  # list of static libraries to link, each object file should be used and not discarded
        LINK_FLAGS                    # list of extra commands to linker
        )
    cmake_parse_arguments(ARG "${options}" "${oneValueRequiredArgs};${oneValueOptionalArgs}" "${multiValueArgs}" ${ARGN} )

    # sanity checks
    foreach(argName ${oneValueRequiredArgs})
        if (NOT ARG_${argName})
            message(SEND_ERROR "Argument '${argName}' is required.")
        endif()
    endforeach()
    if (ARG_UNPARSED_ARGUMENTS)
        message(SEND_ERROR "Unexpected parameters have passed to function: ${ARG_UNPARSED_ARGUMENTS}")
    endif()

    # adding files to target
    set(includeSearch)
    set(sourceSearch)
    foreach(directory ${ARG_ROOT} ${ARG_ADDITIONAL_SOURCE_DIRS})
        list(APPEND includeSearch ${directory}/*.h ${directory}/*.hpp)
        list(APPEND sourceSearch  ${directory}/*.cpp)
    endforeach()

    file(GLOB_RECURSE includes ${includeSearch})
    file(GLOB_RECURSE sources  ${sourceSearch})

    # remove unnecessary directories
    foreach(excludedDir ${ARG_EXCLUDED_SOURCE_PATHS})
        list(FILTER includes EXCLUDE REGEX "${excludedDir}.*")
        list(FILTER sources EXCLUDE REGEX "${excludedDir}.*")
    endforeach()

    source_group("include" FILES ${includes})
    source_group("src"     FILES ${sources})

    set(all_sources)
    list(APPEND all_sources ${sources} ${includes} ${ARG_OBJECT_FILES})

    # defining a target
    if (ARG_TYPE STREQUAL EXECUTABLE)
        add_executable(${ARG_NAME} ${all_sources})
    elseif(ARG_TYPE STREQUAL STATIC OR ARG_TYPE STREQUAL SHARED)
        add_library(${ARG_NAME} ${ARG_TYPE} ${all_sources})
    else()
        message(SEND_ERROR "Invalid target type ${ARG_TYPE} specified for target name ${ARG_NAME}")
    endif()

    ieTargetLinkWholeArchive(${ARG_NAME} ${ARG_LINK_LIBRARIES_WHOLE_ARCHIVE})

    if (ARG_DEFINES)
        target_compile_definitions(${ARG_NAME} PRIVATE ${ARG_DEFINES})
    endif()
    if (ARG_INCLUDES)
        target_include_directories(${ARG_NAME} PRIVATE ${ARG_INCLUDES})
    endif()
    if (ARG_LINK_LIBRARIES)
        target_link_libraries(${ARG_NAME} PRIVATE ${ARG_LINK_LIBRARIES})
    endif()
    if (ARG_DEPENDENCIES)
        add_dependencies(${ARG_NAME} ${ARG_DEPENDENCIES})
    endif()
    if (ARG_LINK_FLAGS)
        get_target_property(oldLinkFlags ${ARG_NAME} LINK_FLAGS)
        string(REPLACE ";" " " ARG_LINK_FLAGS "${ARG_LINK_FLAGS}")
        set_target_properties(${ARG_NAME} PROPERTIES LINK_FLAGS "${oldLinkFlags} ${ARG_LINK_FLAGS}")
    endif()
    if (ARG_ADD_CPPLINT)
        # code style
        add_cpplint_target(${ARG_NAME}_cpplint FOR_TARGETS ${ARG_NAME})
    endif()
    if (ARG_ADD_CLANG_FORMAT)
        # code style
        add_clang_format_target(${ARG_NAME}_clang FOR_TARGETS ${ARG_NAME})
    endif()
    if (ARG_DEVELOPER_PACKAGE)
        # developer package
        openvino_developer_export_targets(COMPONENT ${ARG_DEVELOPER_PACKAGE}
                                          TARGETS ${ARG_NAME})
    endif()
    if(WIN32)
        # Provide default compile pdb name equal to target name
        set_target_properties(${ARG_NAME} PROPERTIES COMPILE_PDB_NAME ${ARG_NAME})
        message("ARG_NAME: ${ARG_NAME}")
        target_link_options(${ARG_NAME} PRIVATE /PDBALTPATH:$<TARGET_PDB_FILE_NAME:${ARG_NAME}>)
    endif()
endfunction()

function(ov_add_target)
    addIeTarget(${ARGV})
endfunction()

#[[
Wrapper function over addIeTarget, that also adds a test with the same name.
You could use
addIeTargetTest( ... LABELS labelOne labelTwo )
also to provide labels for that test.
Important: you MUST pass LABELS as last argument, otherwise it will consume any parameters that come after.
#]]
function(addIeTargetTest)
    set(options
        )
    set(oneValueRequiredArgs
        NAME
        )
    set(oneValueOptionalArgs
        COMPONENT
        )
    set(multiValueArgs
        LABELS
        )
    cmake_parse_arguments(ARG "${options}" "${oneValueRequiredArgs};${oneValueOptionalArgs}" "${multiValueArgs}" ${ARGN} )
    if (NOT DEFINED ARG_COMPONENT)
        set(ARG_COMPONENT tests)
    endif()

    addIeTarget(TYPE EXECUTABLE NAME ${ARG_NAME} ${ARG_UNPARSED_ARGUMENTS})

    add_test(NAME ${ARG_NAME} COMMAND ${ARG_NAME})
    set_property(TEST ${ARG_NAME} PROPERTY LABELS ${ARG_LABELS})

    install(TARGETS ${ARG_NAME}
            RUNTIME DESTINATION tests
            COMPONENT ${ARG_COMPONENT}
            EXCLUDE_FROM_ALL)
endfunction()

function(ov_add_test_target)
    addIeTargetTest(${ARGV})
endfunction()
