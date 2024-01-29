function (create_tweaked_headers)
  # Create ADD_TEST() command string
  # - Extract and remove testname from ARGV
  # - Add inner quotes to test arguments
  # - Add "ADD_TEST()", and first and last quote
  # Append result to CTESTTESTS
  list(GET ARGV 0 testname)
  list(REMOVE_AT ARGV 0)
  string (REPLACE ";" "\" \"" TEST_ARGS "${ARGV}")
  set(test_to_add "ADD_TEST(${testname} \"${TEST_ARGS}\")")
  list(APPEND CTESTTESTS ${test_to_add})
  SET(CTESTTESTS ${CTESTTESTS} PARENT_SCOPE)

  configure_file(<input> <output> COPYONLY)

endfunction()


# TODO:
# Fetch the tester sources
# Search for the FAKE(ret, name, fname, args) to retrieve the FAKED fns
# Retrieve the include paths
# Traverse each incl path in order to locate where the fn is defined. Subs in all where it is found
# Create the fake.xxx.h file
# Add target_include_directories(.. BEFORE) for the SUT

# El folder de guardar movidas sera ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${TEST_TARGET}.dir/gen