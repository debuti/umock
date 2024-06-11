
# Universal Mock (UMock) for CMake based tests
# Borja García <debuti@gmail.com>

cmake_minimum_required(VERSION 3.12)

function(_umock_trace msg)
    if(UMOCK_TRACE)
        message("${msg}")
    endif()
endfunction()

function(_umock_info msg)
    if(UMOCK_VERBOSE)
        message("${msg}")
    endif()
endfunction()

function(_umock_search_mocks_in_tester)
    set(flags)
    set(singleargs FILE OUT)
    set(multiargs)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if(NOT ARG_FILE)
        message(FATAL_ERROR "You must provide a valid tester file path")
    endif()
    if(NOT ARG_OUT)
        message(FATAL_ERROR "You must provide an output variable")
    endif()

    _umock_trace("Searching for mocks in ${ARG_FILE}")
    file(READ ${ARG_FILE} testf_data)
    set(SEARCHMOCK "MOCK[ \t\r\n]*\\\([ \t\r\n]*([^,]*)[ \t\r\n]*,[ \t\r\n]*([^,]*)[ \t\r\n]*,[ \t\r\n]*([^,]*)[ \t\r\n]*,[ \t\r\n]*(\\\([^\\\)]*\\\))[ \t\r\n]*\\\)")
    string(REGEX MATCHALL ${SEARCHMOCK} matches ${testf_data}) 
    foreach(match ${matches})
        string(REGEX MATCH ${SEARCHMOCK} _ ${match})
        set(mock_rc ${CMAKE_MATCH_1})
        set(mock_fn ${CMAKE_MATCH_2})
        set(mock_args ${CMAKE_MATCH_4})
        list(APPEND MOCKS ${mock_rc} ${mock_fn} ${mock_args})
    endforeach()
    set(${ARG_OUT} ${MOCKS} PARENT_SCOPE)
endfunction()

function(_umock_contains_fn)
    set(flags)
    set(singleargs FILE FN OUT)
    set(multiargs)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if(NOT ARG_FILE)
        message(FATAL_ERROR "You must provide a valid tester file path")
    endif()
    if(NOT ARG_FN)
        message(FATAL_ERROR "You must provide a valid fn name")
    endif()
    if(NOT ARG_OUT)
        message(FATAL_ERROR "You must provide an output variable")
    endif()

    file(READ ${ARG_FILE} fdata)
    if (fdata STREQUAL "")
        set(${ARG_OUT} NO PARENT_SCOPE)
        return()
    endif()
    # FIXME : Consider this (fn()) and this ()fn()
    set(SEARCHFN "[ \t\r\n]+[\*]?${ARG_FN}[ \t\r\n]*\\\(")
    string(REGEX MATCHALL ${SEARCHFN} matches ${fdata}) 
    if (matches)
      set(${ARG_OUT} YES PARENT_SCOPE)
    else()
      set(${ARG_OUT} NO PARENT_SCOPE)
    endif()
endfunction()

function(_umock_extract_includes)
    # Parameter parsing and validation
    set(flags)
    set(singleargs FILE OUT)
    set(multiargs)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if(NOT ARG_FILE)
        message(FATAL_ERROR "You must provide a valid tester file path")
    endif()
    if(NOT ARG_OUT)
        message(FATAL_ERROR "You must provide an output variable")
    endif()

    file(READ ${ARG_FILE} fdata)
    set(SEARCHINCLUDES "#[ \t\r\n]*include[ \t\r\n]+[\"<]([^\">]+)[\">]")
    string(REGEX MATCHALL ${SEARCHINCLUDES} matches ${fdata}) 
    foreach(match ${matches})
        string(REGEX MATCH ${SEARCHINCLUDES} _ ${match}) 
        list(APPEND INCLUDES ${CMAKE_MATCH_1})
    endforeach()
    set(${ARG_OUT} ${INCLUDES} PARENT_SCOPE)
endfunction()

#! _umock_search_mocks_in_sut : search mocks inside the system-under-test
#
# This fn searches for the mocks inside all SUT files, and returns all the
# includes of that file.
#
# \param:FILE SUT source file
# \param:RC The return value of the mock
# \param:FN The fn name of the mock
# \param:ARGS The args of the mock 
# \param:OUT Variable to dump the list of includes into 
#
function(_umock_search_mocks_in_sut)
    set(flags)
    set(singleargs FILE RC FN ARGS OUT)
    set(multiargs)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if(NOT ARG_FILE)
        message(FATAL_ERROR "You must provide a valid SUT file path")
    endif()
    if((NOT ARG_RC) OR (NOT ARG_FN) OR (NOT ARG_ARGS))
        message(FATAL_ERROR "You must provide a valid fn signature")
    endif()
    if(NOT ARG_OUT)
        message(FATAL_ERROR "You must provide an output variable")
    endif()

    _umock_trace("  Searching for ${ARG_FN} in ${ARG_FILE}")
    _umock_contains_fn(FILE ${ARG_FILE}
                       FN ${ARG_FN}
                       OUT is_found)
    # If found in this file, get this file includes
    if (is_found)
        _umock_info("   ${ARG_FN} usage found in ${ARG_FILE}")
        _umock_extract_includes(FILE ${ARG_FILE}
                                OUT includes
        )
        set(${ARG_OUT} ${includes} PARENT_SCOPE)
    endif()
endfunction()

#! _umock_traverse_incs_and_incpaths : search mocks inside the includes
#
# This fn searches for the fn to mock inside the includes, recursively.
#
# \param:RC The return value of the mock
# \param:FN The fn name of the mock
# \param:ARGS The args of the mock 
# \group:INCS Initial set of includes
# \group:INCPATHS Include paths to work with
# \param:OUT Variable to dump the list of selected includes into 
#
function(_umock_traverse_incs_and_incpaths)
    set(flags)
    set(singleargs RC FN ARGS OUT)
    set(multiargs INCS INCPATHS)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if((NOT ARG_RC) OR (NOT ARG_FN) OR (NOT ARG_ARGS))
        message(FATAL_ERROR "You must provide a valid fn signature")
    endif()
    if(NOT ARG_INCS)
        message(FATAL_ERROR "You must provide the initial set of includes")
    endif()
    if(NOT ARG_INCPATHS)
        message(FATAL_ERROR "You must provide the include paths")
    endif()
    if(NOT ARG_OUT)
        message(FATAL_ERROR "You must provide an output variable")
    endif()

    set(incs ${ARG_INCS})
    set(used "")
    set(out "")
    while(incs)
        list(POP_FRONT incs inc)
        if(${inc} IN_LIST used)
          continue()
        endif()
        list(APPEND used ${inc})
        _umock_trace("     Include ${inc}")
        foreach(incpath ${ARG_INCPATHS})
            if(EXISTS ${incpath}/${inc} AND NOT IS_DIRECTORY ${incpath}/${inc})
                _umock_trace("      Living in ${incpath}/${inc}")
                _umock_contains_fn(FILE ${incpath}/${inc}
                                   FN ${ARG_FN}
                                   OUT is_found)
                if(is_found)
                    _umock_trace("       ${ARG_FN} found in ${incpath}/${inc}")
                    list(APPEND out ${incpath} ${inc})
                else()
                    _umock_trace("       Not found, searching in inherited includes")
                    _umock_extract_includes(FILE ${incpath}/${inc}
                                            OUT new_incs)
                    list(PREPEND incs ${new_incs})
                endif()
                break()
            endif()
        endforeach()
    endwhile()
    set(${ARG_OUT} ${out} PARENT_SCOPE)
    return()
endfunction()

#! _umock_get_default_incpaths : search default include paths for the selected compiler
#
# CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES cannot be used as it is not 100% correct
#
#TODO: Add OUT parameter to specify the variable
function(_umock_get_default_incpaths)
    # https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_COMPILER_ID.html
    if (NOT CMAKE_C_COMPILER_ID)
        message(FATAL_ERROR "Compiler unknown to UMock")
    endif()
    string(REPLACE " " ";" CMAKE_C_FLAGS_AS_LIST "${CMAKE_C_FLAGS}")
    if (CMAKE_C_COMPILER_ID STREQUAL "Clang") # Clang
        message(FATAL_ERROR "Clang not implemented yet")
    elseif (CMAKE_C_COMPILER_ID STREQUAL "GNU") # GCC, QCC
        get_filename_component(CMAKE_C_COMPILER_NAME ${CMAKE_C_COMPILER} NAME)
        if (CMAKE_C_COMPILER_NAME STREQUAL "qcc")
            execute_process(COMMAND ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS_AS_LIST} -vvv
                    OUTPUT_QUIET
                    ERROR_VARIABLE qccinfo)
            # COMPILER_INCLUDES=$(QNX_TARGET)/usr/include:

            set(SEARCHCONF "looking for [^ \t\r\n]+ in ([^ \t\r\n]+)")
            string(REGEX MATCHALL ${SEARCHCONF} matches ${qccinfo})
            if (matches)
                foreach(match ${matches})
                    string(REGEX MATCH ${SEARCHCONF} _ ${match})
                    list(APPEND CONFS ${CMAKE_MATCH_1})
                endforeach()
                foreach(conf ${CONFS})
                    file(READ ${conf} conf_data)
                    set(SEARCHINCS "# COMPILER_INCLUDES=([^ \t\r\n]+)")
                    string(REGEX MATCHALL ${SEARCHINCS} matches ${conf_data})
                    foreach(match ${matches})
                        string(REGEX MATCH ${SEARCHINCS} _ ${match})
                        # FIXME: Replace any $(..) with $ENV{..}
                        string(REPLACE "$(QNX_TARGET)" "$ENV{QNX_TARGET}" INCS_LIST "${CMAKE_MATCH_1}")
                        string(REPLACE "$(QNX_HOST)" "$ENV{QNX_HOST}" INCS_LIST "${INCS_LIST}")
                        string(REPLACE ":" ";" INCS_LIST "${INCS_LIST}")
                        foreach(inc ${INCS_LIST})
                            list(APPEND INCS ${inc})
                        endforeach()
                    endforeach()
                endforeach()
                set(DEFAULT_INCLUDES ${INCS} PARENT_SCOPE)
            else()
                message(FATAL_ERROR "Error in QCC default includes parsing")
            endif()
        else()
            execute_process(COMMAND ${CMAKE_C_COMPILER} -xc -E -v /dev/null
                    OUTPUT_QUIET
                    ERROR_VARIABLE gccinfo)

            set(SEARCHINCS "#include .* starts here:.*End of search list.")
            string(REGEX MATCHALL ${SEARCHINCS} match ${gccinfo}) 
            if (match)
                set(SEARCHINC "\n ([^\n]+)")
                string(REGEX MATCHALL ${SEARCHINC} matches ${match})
                foreach(match ${matches})
                    string(REGEX MATCHALL ${SEARCHINC} _ ${match})
                    list(APPEND INCS ${CMAKE_MATCH_1})
                endforeach()
                set(DEFAULT_INCLUDES ${INCS} PARENT_SCOPE)
            endif()
        endif()
    elseif (CMAKE_C_COMPILER_ID STREQUAL "Intel") # Intel C++
        message(FATAL_ERROR "Intel not implemented yet")
    elseif (CMAKE_C_COMPILER_ID STREQUAL "MSVC") # VS C++
        message(FATAL_ERROR "MSVC not implemented yet")
    else()
        message(FATAL_ERROR "Compiler unknown to UMock")
    endif()
endfunction()

set(UMOCK_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "" FORCE)

function(umock_this)
    set(flags)
    set(singleargs SUT TESTER)
    set(multiargs)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if((NOT ARG_SUT) OR (NOT (TARGET ${ARG_SUT})))
        message(FATAL_ERROR "You must provide a valid system under test target")
    endif()
    if((NOT ARG_TESTER) OR (NOT (TARGET ${ARG_TESTER})))
        message(FATAL_ERROR "You must provide a valid tester target")
    endif()
    
    if(NOT DEFINED UMOCK_MODE)
        set(UMOCK_MODE "NARROW")
    endif()
    # Reference to umock static include
    set(UMOCK_INC ${UMOCK_BASE_DIR}/../include)
    # Ephimeral folder for generated artifacts
    set(UMOCK_TMP ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${ARG_TESTER}.dir/gen)

    _umock_get_default_incpaths()
    _umock_trace("System include paths:")
    foreach(defp ${DEFAULT_INCLUDES})
        _umock_trace("  - ${defp}")
    endforeach()

    get_target_property(${ARG_SUT}_src ${ARG_SUT} SOURCES)
    _umock_trace("SUT sources:")
    foreach(sutf ${${ARG_SUT}_src})
        _umock_trace("  - ${sutf}")
    endforeach()

    get_target_property(${ARG_SUT}_includes ${ARG_SUT} INCLUDE_DIRECTORIES)
    set(${ARG_SUT}_incpaths ${${ARG_SUT}_includes} ${DEFAULT_INCLUDES})
    _umock_trace("SUT include paths:")
    foreach(sutf ${${ARG_SUT}_includes})
        _umock_trace("  - ${sutf}")
    endforeach()

    get_target_property(${ARG_TESTER}_src      ${ARG_TESTER} SOURCES)
    _umock_trace("Tester sources:")
    foreach(testf ${${ARG_TESTER}_src})
        _umock_trace("  - ${testf}")
    endforeach()
 
    # Search for the fns to mock
    foreach(testf ${${ARG_TESTER}_src})
        _umock_search_mocks_in_tester(FILE ${testf} 
                                      OUT mocks)

        while(mocks)
            list(POP_FRONT mocks mock_rc mock_fn mock_args)
            _umock_info(" Mock: ${mock_rc} ${mock_fn}${mock_args} found in ${testf}")

            if(UMOCK_MODE STREQUAL "NARROW")
                # Search for the includes of the SUT sources that consume that mock
                foreach(sutf ${${ARG_SUT}_src})
                    _umock_search_mocks_in_sut(FILE ${sutf}
                                            RC ${mock_rc} 
                                            FN ${mock_fn}
                                            ARGS ${mock_args}
                                            OUT includes)
                    if(NOT includes)
                        continue()
                    endif()

                    # mock found in sut source, relevant includes to inject into
                    _umock_trace("    Includes: ${includes}")

                    # Traverse include folders to locate each include file that contains the fn to mock
                    _umock_traverse_incs_and_incpaths(
                        RC ${mock_rc} 
                        FN ${mock_fn}
                        ARGS ${mock_args}
                        INCS ${includes}
                        INCPATHS ${${ARG_SUT}_incpaths}
                        OUT selected
                    )
                    if(NOT selected)
                        message(FATAL_ERROR "UMock was unable to patch the system under test for mock ${mock_fn}")
                    endif()
                    
                    _umock_trace(" Includes where the mock fn should be placed: ${selected}")
                    
                    set(dpath ${UMOCK_TMP}/${sutf})
                    if(NOT EXISTS ${dpath})
                        file(MAKE_DIRECTORY ${dpath})
                        set_property(SOURCE ${sutf} APPEND PROPERTY INCLUDE_DIRECTORIES ${dpath} ${UMOCK_INC})
                    endif()

                    if (selected)
                        _umock_add_mockbody_file(
                            RC ${mock_rc} 
                            FN ${mock_fn}
                            ARGS ${mock_args}
                            TARGET ${dpath}/umock.${mock_fn}.h 
                        )
                    endif()

                    while(selected)
                        list(POP_FRONT selected incpath inc)
                        _umock_trace("File to tune: ${incpath}//${inc} -> ${dpath}/${inc}")
                        get_filename_component(dpath_parent ${dpath}/${inc} DIRECTORY)
                        if(NOT EXISTS ${dpath_parent})
                            file(MAKE_DIRECTORY ${dpath_parent})
                        endif()
                        if(NOT EXISTS ${dpath}/${inc})
                            file(COPY ${incpath}/${inc}
                                DESTINATION ${dpath_parent}
                                )
                        endif()
                        file(APPEND ${dpath}/${inc}
                            "\n"
                            "/* UMock hook */\n"
                            "#include \"umock.${mock_fn}.h\""
                            )
                    endwhile()
                endforeach()
            elseif(UMOCK_MODE STREQUAL "WIDE")
                # Create the mockbody first
                _umock_add_mockbody_file(
                    RC ${mock_rc} 
                    FN ${mock_fn}
                    ARGS ${mock_args}
                    TARGET ${UMOCK_TMP}/common/umock.${mock_fn}.h
                )
                    
                # Search each include folder
                foreach(incpath ${${ARG_SUT}_incpaths})
                    # Try to locate the mocked signature in any of the files
                    _umock_traverse_incpaths(
                        RC ${mock_rc} 
                        FN ${mock_fn}
                        ARGS ${mock_args}
                        INCPATH ${incpath}
                        RELPATH ""
                        OUT selectedfiles
                    )
                    if(NOT selectedfiles)
                        continue()
                    endif()

                    _umock_trace("  Selected files: ${selectedfiles}")

                    set(dpath ${UMOCK_TMP}/common/${incpath})

                    # For each file that contains the mocked signature
                    foreach(selectedfile ${selectedfiles})

                        # Check if file exists, otherwise copy it into the ephimeral folder
                        if(NOT EXISTS ${dpath}/${selectedfile})
                            get_filename_component(selectedfile_parent ${dpath}/${selectedfile} DIRECTORY)
                            file(MAKE_DIRECTORY ${selectedfile_parent})
                            file(COPY ${incpath}/${selectedfile}
                                DESTINATION ${selectedfile_parent}
                            )
                        endif()

                        # Open the file and append the hook
                        file(APPEND ${dpath}/${selectedfile}
                            "\n"
                            "/* UMock hook */\n"
                            "#include \"umock.${mock_fn}.h\""
                            )
                    endforeach()
                endforeach()
            endif()
            _umock_trace("")
        endwhile()
    endforeach()

    if(UMOCK_MODE STREQUAL "WIDE")
        set(new_${ARG_SUT}_incpaths "${UMOCK_INC};${UMOCK_TMP}/common")
        foreach(incpath ${${ARG_SUT}_incpaths})
            if(EXISTS ${UMOCK_TMP}/common/${incpath})
                list(APPEND new_${ARG_SUT}_incpaths ${UMOCK_TMP}/common/${incpath})
            endif()
            list(APPEND new_${ARG_SUT}_incpaths ${incpath})
        endforeach()
        message("new_${ARG_SUT}_incpaths: ${new_${ARG_SUT}_incpaths}")
        target_include_directories(${ARG_SUT} PRIVATE ${new_${ARG_SUT}_incpaths})
    endif()

    target_include_directories(${ARG_TESTER} PRIVATE ${UMOCK_INC})
endfunction()

#! _umock_traverse_incpaths : search mocks inside the includes
#
# This fn searches for the fn to mock inside the includes, recursively.
#
# \param:RC The return value of the mock
# \param:FN The fn name of the mock
# \param:ARGS The args of the mock 
# \group:INCPATH Include path to work with
# \param:RELPATH The current relative path. Initialize to ""
# \param:OUT Variable to dump the list of selected includes into 
#
function(_umock_traverse_incpaths)
    set(flags)
    set(singleargs RC FN ARGS RELPATH INCPATH OUT)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if((NOT ARG_RC) OR (NOT ARG_FN) OR (NOT ARG_ARGS))
        message(FATAL_ERROR "You must provide a valid fn signature")
    endif()
    if(NOT ARG_INCPATH)
        message(FATAL_ERROR "You must provide the include paths")
    endif()
    if(NOT ARG_OUT)
        message(FATAL_ERROR "You must provide an output variable")
    endif()

    _umock_trace("  Include path: ${incpath}")
    file(GLOB_RECURSE items RELATIVE ${ARG_INCPATH} ${ARG_INCPATH}/*.h)
    foreach(item ${items})
        _umock_contains_fn(FILE ${ARG_INCPATH}/${item}
            FN ${mock_fn}
            OUT is_found)
        if(is_found)
            list(APPEND out ${item})
            _umock_trace("   ${mock_fn} found in ${ARG_INCPATH}/${item}")
        endif()
    endforeach()
    set(${ARG_OUT} ${out} PARENT_SCOPE)
endfunction()



#! _umock_add_mockbody_file : creates the mock body file
#
# \param:RC The return value of the mock
# \param:FN The fn name of the mock
# \param:ARGS The args of the mock 
# \group:TARGET Full path to the target
#
function(_umock_add_mockbody_file)
    set(flags)
    set(singleargs RC FN ARGS TARGET)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if((NOT ARG_RC) OR (NOT ARG_FN) OR (NOT ARG_ARGS))
        message(FATAL_ERROR "You must provide a valid fn signature")
    endif()
    if(NOT ARG_TARGET)
        message(FATAL_ERROR "You must provide the target file")
    endif()

    string(REGEX REPLACE "^[ \t\r\n]*\\\(" "" mock_args_trimmed ${ARG_ARGS})
    string(REGEX REPLACE "\\\)[ \t\r\n]*$" "" mock_args_trimmed ${mock_args_trimmed})
    string(REPLACE "," ";" mock_args_list ${mock_args_trimmed})
    set(mock_argnames "")
    while(mock_args_list)
        list(POP_FRONT mock_args_list param_sign)
        string(REGEX MATCH "[A-Za-z0-9_]+$" mock_argname ${param_sign})
        list(APPEND mock_argnames ${mock_argname})
    endwhile()
    string(REPLACE ";" "," mock_argnames ${mock_argnames})
    file(WRITE ${ARG_TARGET} 
        "#ifndef _umock_${ARG_FN}_h_\n"
        "#define _umock_${ARG_FN}_h_\n"
        "#include \"umock.h\"\n"
        "typedef ${ARG_RC}(*${ARG_FN}_fn)${ARG_ARGS};\n"
        "MOCKBODY(${ARG_FN}, ${ARG_RC} ${ARG_FN}_test${ARG_ARGS}, (${mock_argnames}))\n"
        "#define ${ARG_FN} ${ARG_FN}_test\n"
        "#endif\n"
        )
endfunction()
