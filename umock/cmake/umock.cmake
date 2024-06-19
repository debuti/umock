
# Universal Mock (umock) for CMake based tests
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


#! _umock_get_default_incpaths : search default include paths for the selected compiler
#
# CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES cannot be used as it is not 100% correct
#
#TODO: Add OUT parameter to specify the variable
function(_umock_get_default_incpaths)
    # https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_COMPILER_ID.html
    if (NOT CMAKE_C_COMPILER_ID)
        message(FATAL_ERROR "Compiler unknown to umock")
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
        message(FATAL_ERROR "Compiler unknown to umock")
    endif()
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
    # For every header in the incpath
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

    file(WRITE ${ARG_TARGET} 
        "#ifndef _umock_${ARG_FN}_h_\n"
        "#define _umock_${ARG_FN}_h_\n"
        "${ARG_RC} ${ARG_FN}_test${ARG_ARGS};\n"
        "#define ${ARG_FN} ${ARG_FN}_test\n"
        "#endif\n"
        )
endfunction()


#! _umock_append_to_mocksupport_file : creates the mock support file and appends stuff to it
#
# \param:RC The return value of the mock
# \param:FN The fn name of the mock
# \param:ARGS The args of the mock 
# \group:TARGET Full path to the target
#
function(_umock_append_to_mocksupport_file)
    set(flags)
    set(singleargs RC FN ARGS INC TARGET)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if((NOT ARG_RC) OR (NOT ARG_FN) OR (NOT ARG_ARGS))
        message(FATAL_ERROR "You must provide a valid fn signature")
    endif()
    if(NOT ARG_INC)
        message(FATAL_ERROR "You must provide the include file")
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
    list(JOIN mock_argnames "," mock_argnames)
    file(APPEND ${ARG_TARGET} 
        "#ifndef _umock_${ARG_FN}_c_\n"
        "#define _umock_${ARG_FN}_c_\n"
        "#include \"${ARG_INC}\"\n"
        "#include \"umock.h\"\n"
        "typedef ${ARG_RC}(*${ARG_FN}_fn)${ARG_ARGS};\n"
        "MOCKENTRY(${ARG_FN}, ${ARG_RC} ${ARG_FN}_test${ARG_ARGS}, (${mock_argnames}))\n"
        "#endif\n"
        )
endfunction()


set(UMOCK_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "" FORCE)


#! umock_this : mock all the defined functions in the tester
#
# \param:SUTS The systems under test CMake targets to mock
# \param:TESTER The tester CMake target to read the mock targets from
#
function(umock_this)
    set(flags)
    set(singleargs TESTER)
    set(multiargs SUTS)
    cmake_parse_arguments(ARG "${flags}" "${singleargs}" "${multiargs}" ${ARGN})
    if(NOT ARG_SUTS)
        message(FATAL_ERROR "You must provide a valid system under test target")
    endif()
    foreach(ARG_SUT ${ARG_SUTS})
        if((NOT ARG_SUT) OR (NOT (TARGET ${ARG_SUT})))
            message(FATAL_ERROR "You must provide a valid system under test target: ${ARG_SUT}")
        endif()
    endforeach()
    if((NOT ARG_TESTER) OR (NOT (TARGET ${ARG_TESTER})))
        message(FATAL_ERROR "You must provide a valid tester target")
    endif()
    
    if(NOT DEFINED UMOCK_MOCK_MAGAZINE_MAX)
        set(UMOCK_MOCK_MAGAZINE_MAX 32)
    endif()

    # Reference to umock static include
    set(UMOCK_INCPATH ${UMOCK_BASE_DIR}/../include)

    # Ephimeral folder for generated artifacts
    set(UMOCK_TMP ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${ARG_TESTER}.dir/gen)

    _umock_get_default_incpaths()
    _umock_trace("System include paths:")
    foreach(defp ${DEFAULT_INCLUDES})
        _umock_trace("  - ${defp}")
    endforeach()

    get_target_property(${ARG_TESTER}_src ${ARG_TESTER} SOURCES)
    _umock_trace("Tester sources:")
    foreach(testf ${${ARG_TESTER}_src})
        _umock_trace("  - ${testf}")
    endforeach()

    set(PREVIOUS_MOCKS "")

    # Search for the fns to mock
    foreach(testf ${${ARG_TESTER}_src})
        _umock_search_mocks_in_tester(FILE ${testf} 
            OUT mocks
        )

        while(mocks)
            list(POP_FRONT mocks mock_rc mock_fn mock_args)

            # Check if the mock has already been processed
            if (${mock_fn} IN_LIST PREVIOUS_MOCKS)
                continue()
            endif()
            list(APPEND PREVIOUS_MOCKS ${mock_fn})

            _umock_info(" FTBM: ${mock_rc} ${mock_fn}${mock_args} found in ${testf}")

            _umock_add_mockbody_file(
                RC ${mock_rc} 
                FN ${mock_fn}
                ARGS ${mock_args}
                TARGET ${UMOCK_TMP}/common/umock.${mock_fn}.h
            )

            # Search in each SUT target
            foreach(ARG_SUT ${ARG_SUTS})
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
                   
                # Search each include folder
                foreach(incpath ${${ARG_SUT}_incpaths})
                    # Try to locate the mocked signature in any of the files
                    _umock_traverse_incpaths(
                        RC ${mock_rc} 
                        FN ${mock_fn}
                        ARGS ${mock_args}
                        INCPATH ${incpath}
                        RELPATH ""
                        OUT includes
                    )
                    if(NOT includes)
                        # The incpath was not containing the ftbm in any of its headers
                        continue()
                    endif()

                    _umock_info(" Includes where the mock fn should be placed: ${incpath}/ ${includes}")

                    set(dpath ${UMOCK_TMP}/${ARG_SUT}/${incpath})

                    # For each file that contains the ftbm signature
                    foreach(include ${includes})
                        # Check if file exists, otherwise copy it into the ephimeral folder
                        if(NOT EXISTS ${dpath}/${include})
                            get_filename_component(include_parent ${dpath}/${include} DIRECTORY)
                            file(MAKE_DIRECTORY ${include_parent})
                            file(COPY ${incpath}/${include}
                                DESTINATION ${include_parent}
                            )
                        endif()

                        file(READ ${dpath}/${include} fdata)
                        set(SEARCHINC "umock.${mock_fn}.h")
                        string(REGEX MATCHALL ${SEARCHINC} matches ${fdata}) 
                        if (matches)
                            _umock_info(" File was already patched")
                            continue()
                        endif()

                        # Open the file and append the card trick
                        file(APPEND ${dpath}/${include}
                            "\n"
                            "/* umock hook */\n"
                            "#include \"umock.${mock_fn}.h\""
                        )

                        _umock_append_to_mocksupport_file(
                            RC ${mock_rc} 
                            FN ${mock_fn}
                            ARGS ${mock_args}
                            INC ${include}
                            TARGET ${UMOCK_TMP}/common/umock_support.c
                        )
                    endforeach(include ${includes})
                endforeach(incpath ${${ARG_SUT}_incpaths})
                _umock_trace("")
            endforeach(ARG_SUT ${ARG_SUTS})
        endwhile(mocks)
    endforeach(testf ${${ARG_TESTER}_src})


    foreach(ARG_SUT ${ARG_SUTS})
        get_target_property(${ARG_SUT}_includes ${ARG_SUT} INCLUDE_DIRECTORIES)
        set(${ARG_SUT}_incpaths ${${ARG_SUT}_includes} ${DEFAULT_INCLUDES})

        # To compile the umock_support.c there is need a for ARG_SUT incpaths 
        target_include_directories(${ARG_TESTER} PRIVATE ${${ARG_SUT}_incpaths})

        # Add the umock and common incpaths to SUT incpaths
        set(new_${ARG_SUT}_incpaths "${UMOCK_INCPATH};${UMOCK_TMP}/common")

        # Add the cardtricks to SUT incpaths
        foreach(incpath ${${ARG_SUT}_incpaths})
            if(EXISTS ${UMOCK_TMP}/${ARG_SUT}/${incpath})
                list(APPEND new_${ARG_SUT}_incpaths ${UMOCK_TMP}/${ARG_SUT}/${incpath})
            endif()
            list(APPEND new_${ARG_SUT}_incpaths ${incpath})
        endforeach()

        target_include_directories(${ARG_SUT} BEFORE PRIVATE ${new_${ARG_SUT}_incpaths})
    endforeach(ARG_SUT ${ARG_SUTS})

    # Set the length of the mock magazine
    target_compile_definitions(${ARG_TESTER} PRIVATE "UMOCK_MOCK_MAGAZINE_MAX=${UMOCK_MOCK_MAGAZINE_MAX}")

    # Append a new source to the tester sources
    target_sources(${ARG_TESTER} PRIVATE ${UMOCK_TMP}/common/umock_support.c)

    # Add umock incpath to tester
    target_include_directories(${ARG_TESTER} BEFORE PRIVATE ${UMOCK_INCPATH})

endfunction()
