
# Universal Mock (UMock) for CMake based tests
# Borja García <debuti@gmail.com>

cmake_minimum_required(VERSION 3.16)

function(_umock_msg msg)
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

    _umock_msg("Searching for mocks in ${ARG_FILE}")
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

    # message("Searching includes in ${ARG_FILE}")
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

    _umock_msg("Searching for ${ARG_FN} in ${ARG_FILE}")
    _umock_contains_fn(FILE ${ARG_FILE}
                       FN ${ARG_FN}
                       OUT is_found)
    # If found in this file, get this file includes
    if (is_found)
        _umock_msg(" ${ARG_FN} usage found.")
        _umock_extract_includes(FILE ${ARG_FILE}
                                OUT includes
        )
        set(${ARG_OUT} ${includes} PARENT_SCOPE)
    endif()
endfunction()

#! _umock_traverse_incpaths : search mocks inside the includes
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
function(_umock_traverse_incpaths)
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
        _umock_msg("  Include ${inc}")
        foreach(incpath ${ARG_INCPATHS})
            if(EXISTS ${incpath}/${inc} AND NOT IS_DIRECTORY ${incpath}/${inc})
                _umock_msg("   Living in ${incpath}/${inc}")
                _umock_contains_fn(FILE ${incpath}/${inc}
                                   FN ${ARG_FN}
                                   OUT is_found)
                if(is_found)
                    _umock_msg("    ${ARG_FN} found in ${incpath}/${inc}")
                    list(APPEND out ${incpath} ${inc})
                else()
                    _umock_msg("    Not found, searching in inherited includes")
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

#TODO: Add OUT parameter to specify the variable
function(_umock_get_default_incpaths)
    # https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_COMPILER_ID.html
    if (NOT CMAKE_C_COMPILER_ID)
        message(FATAL_ERROR "Compiler unknown to UMock")
    endif()
    if (CMAKE_C_COMPILER_ID STREQUAL "Clang") # Clang
    elseif (CMAKE_C_COMPILER_ID STREQUAL "GNU") # GCC
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
    # elseif (CMAKE_C_COMPILER_ID STREQUAL "Intel") # Intel C++
    # elseif (CMAKE_C_COMPILER_ID STREQUAL "MSVC") # VS C++
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
    
    _umock_get_default_incpaths()
    SET(UMOCK_INC ${UMOCK_BASE_DIR}/../include)
    SET(UMOCK_TMP ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${ARG_TESTER}.dir/gen)
    get_target_property(${ARG_SUT}_src      ${ARG_SUT} SOURCES)
    get_target_property(${ARG_SUT}_pub_hdr  ${ARG_SUT} PUBLIC_HEADER)
    get_target_property(${ARG_SUT}_priv_hdr ${ARG_SUT} PRIVATE_HEADER)
    get_target_property(${ARG_SUT}_includes ${ARG_SUT} INCLUDE_DIRECTORIES)
    set(${ARG_SUT}_incpaths ${${ARG_SUT}_includes} ${DEFAULT_INCLUDES})
    get_target_property(${ARG_TESTER}_src      ${ARG_TESTER} SOURCES)
    get_target_property(${ARG_TESTER}_pub_hdr  ${ARG_TESTER} PUBLIC_HEADER)
    get_target_property(${ARG_TESTER}_priv_hdr ${ARG_TESTER} PRIVATE_HEADER)

#     message("\
#     \${ARG_SUT}_src:\t\t${${ARG_SUT}_src}\n\
#     \${ARG_SUT}_pub_hdr:\t\t${${ARG_SUT}_pub_hdr}\n\
#     \${ARG_SUT}_priv_hdr:\t${${ARG_SUT}_priv_hdr}\n\
#     \${ARG_SUT}_incpaths:\t${${ARG_SUT}_incpaths}\n\
#     \${ARG_TESTER}_src:\t\t${${ARG_TESTER}_src}\n\
#     \${ARG_TESTER}_pub_hdr:\t${${ARG_TESTER}_pub_hdr}\n\
#     \${ARG_TESTER}_priv_hdr:\t${${ARG_TESTER}_priv_hdr}\n\
# ")
 
    # Search for the fns to mock
    foreach(testf ${${ARG_TESTER}_src})
        _umock_search_mocks_in_tester(FILE ${testf} 
                                      OUT mocks)

        while(mocks)
            list(POP_FRONT mocks mock_rc mock_fn mock_args)
            _umock_msg("Mock: ${mock_rc} ${mock_fn}${mock_args}")

            # Search for the includes of the SUT sources that consume that mock
            foreach(sutf ${${ARG_SUT}_src})
                _umock_search_mocks_in_sut(FILE ${sutf}
                                           RC ${mock_rc} 
                                           FN ${mock_fn}
                                           ARGS ${mock_args}
                                           OUT includes)
                # mock found in sut source, relevant includes to inject into
                _umock_msg(" Includes: ${includes}")

                # Traverse include folders to locate each include file that contains the fn to mock
                _umock_traverse_incpaths(
                    RC ${mock_rc} 
                    FN ${mock_fn}
                    ARGS ${mock_args}
                    INCS ${includes}
                    INCPATHS ${${ARG_SUT}_incpaths}
                    OUT selected
                )
                _umock_msg(" Includes where the mock fn should be placed: ${selected}")
                
                set(dpath ${UMOCK_TMP}/${sutf})
                if(NOT EXISTS ${dpath})
                    file(MAKE_DIRECTORY ${dpath})
                    set_property(SOURCE ${sutf} APPEND PROPERTY INCLUDE_DIRECTORIES ${dpath} ${UMOCK_INC})
                endif()

                if (selected)
                    string(REGEX REPLACE "^[ \t\r\n]*\\\(" "" mock_args_trimmed ${mock_args})
                    string(REGEX REPLACE "\\\)[ \t\r\n]*$" "" mock_args_trimmed ${mock_args_trimmed})
                    string(REPLACE "," ";" mock_args_list ${mock_args_trimmed})
                    set(mock_argnames "")
                    while(mock_args_list)
                        list(POP_FRONT mock_args_list param_sign)
                        string(REGEX MATCH "[A-Za-z0-9_]+$" mock_argname ${param_sign})
                        list(APPEND mock_argnames ${mock_argname})
                    endwhile()
                    string(REPLACE ";" "," mock_argnames ${mock_argnames})
                    file(WRITE ${dpath}/umock.${mock_fn}.h 
                        "#ifndef _umock_${mock_fn}_h_\n"
                        "#define _umock_${mock_fn}_h_\n"
                        "#include \"umock.h\"\n"
                        "typedef ${mock_rc}(*${mock_fn}_fn)${mock_args};\n"
                        "MOCKBODY(${mock_fn}, ${mock_rc} ${mock_fn}_test${mock_args}, (${mock_argnames}))\n"
                        "#define ${mock_fn} ${mock_fn}_test\n"
                        "#endif\n"
                        )
                endif()

                while(selected)
                    list(POP_FRONT selected incpath inc)
                    _umock_msg("File to tune: ${incpath}//${inc} -> ${dpath}/${inc}")
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
            _umock_msg("")
        endwhile()
    endforeach()

    target_include_directories(${ARG_TESTER} PRIVATE ${UMOCK_INC})

endfunction()
