# brst-binding-template — mandatory baseline build entry point
#
# This CMakeLists.txt fulfils the libBeresta org-wide baseline for
# `brst-binding-<lang>` repositories (README.md + CMakeLists.txt). It exists
# to build the libBeresta library so that the ECL bindings can load and use.
#
# This binding template uses static library `libbrst.a` and link it statically.
#
# Three modes are supported:
#
# 1. Vendored source mode:
#      Drop libBeresta source into ext/libBeresta/ (e.g. via git submodule or
#      tarball) and build from this directory:
#          cmake -S . -B build
#          cmake --build build
#
# 2. Relative source mode (multiple bindings development):
#      libBeresta sources expected to be relative to
#      binding repositories path like
#
#      libberesta/
#      brst-binding-ecl/
#      brst-binding-ruby/
#      ... and so on ...
#
#      Build system will check if sources are available by ../libberesta
#      path and if yes use it from that location.
#
#      Build commands are the same:
#          cmake -S . -B build
#          cmake --build build
#
# 3. External source mode (development convenience):
#      Pass -DLIBBRST_SOURCE_DIR=/path/to/libBeresta clone:
#          cmake -S . -B build -DLIBBRST_SOURCE_DIR=$HOME/src/libBeresta
#          cmake --build build
#

project(brst-binding-template)
cmake_minimum_required(VERSION 3.20)

find_program(
    ECL_EXE
  NAMES
    ecl
)

set(ECL_BINARY)

if (NOT EXISTS ${ECL_BINARY})
  if ("${ECL_EXE}" STREQUAL "ECL_EXE-NOTFOUND")
    message(FATAL_ERROR "`ecl` executable could not be found!")
  else()
    set(ECL_BINARY ${ECL_EXE})
  endif()
endif()

set(LIBBRST_REL_DIR   "../libBeresta")
set(LIBBRST_BUILD_DIR "libBeresta-build")
set(LIBBRST_EXT_DIR   "ext/libBeresta")

set(LIBBRST_SOURCE_DIR)

set(BRST_PROBE_FILE "gen/data/gen.cmake")

# Check direct path
message(DEBUG "Probing ${LIBBRST_SOURCE_DIR}/${BRST_PROBE_FILE} ...")

if(EXISTS "${LIBBRST_SOURCE_DIR}/${BRST_PROBE_FILE}")
  message(NOTICE "libBeresta source found at ${LIBBRST_SOURCE_DIR}.")
else()
  # Check ../libBeresta folder for sources
  message(DEBUG "Probing ${CMAKE_CURRENT_LIST_DIR}/${LIBBRST_REL_DIR}/${BRST_PROBE_FILE} ...")

  if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/${LIBBRST_REL_DIR}/${BRST_PROBE_FILE}")
    set(LIBBRST_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/${LIBBRST_REL_DIR}")
    message(NOTICE "libBeresta source found at ${LIBBRST_SOURCE_DIR}.")
  else()

    # Check ext/libBeresta folder for sources
    message(DEBUG "Probing ${CMAKE_CURRENT_LIST_DIR}/${LIBBRST_EXT_DIR}/${BRST_PROBE_FILE} ...")

    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/${LIBBRST_EXT_DIR}/${BRST_PROBE_FILE}")
      set(LIBBRST_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/${LIBBRST_EXT_DIR}")
      message(NOTICE "libBeresta source found at ${LIBBRST_SOURCE_DIR}.")
    else()
      message(WARNING
        "libBeresta source not found at '${LIBBRST_SOURCE_DIR}'.\n"
        "Either:\n"
        "  - Pass -DLIBBRST_SOURCE_DIR=/path/to/libBeresta, or\n"
        "  - Place this repository source relative to ../libBeresta/, or\n"
        "  - Place libBeresta source in ext/libBeresta/ (e.g. git submodule)\n"
        "Skipping libBeresta build target.")
      return()
    endif()
  endif()
endif()

include(${LIBBRST_SOURCE_DIR}/gen/data/gen.cmake)

set(LIBBRST_SHARED_LIB OFF CACHE BOOL "" FORCE)
set(LIBBRST_EXAMPLES   OFF CACHE BOOL "" FORCE)
set(LIBBRST_TESTS      OFF CACHE BOOL "" FORCE)

add_subdirectory("${LIBBRST_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/${LIBBRST_BUILD_DIR}")

add_custom_target(binding)
add_custom_target(check DEPENDS brst)
add_custom_target(bundle)

add_custom_command(
  TARGET binding
  COMMAND ${ECL_BINARY}
  ARGS --load ${LIBBRST_SOURCE_DIR}/gen/scripts/utils.lisp
       --load ${CMAKE_SOURCE_DIR}/scripts/binding.lisp
       --load ${CMAKE_SOURCE_DIR}/scripts/launcher.lisp --
       ${LIBBRST_SOURCE_DIR}/gen/data/
       ${CMAKE_SOURCE_DIR}/src/
#  COMMAND ${CMAKE_COMMAND} -E copy_if_different
#          ${CMAKE_SOURCE_DIR}/templates/macro.lisp
#          "${CMAKE_SOURCE_DIR}/src/macro.lisp"
)

add_custom_command(
  TARGET check
  COMMAND echo "libBeresta language binding check target"
)

file(READ "version" VER)

install(FILES
     "LICENSE"
     "README.md"
     "version"
     DESTINATION .
)

# Add project folders to include to bundle
# install(DIRECTORY "src"   DESTINATION .)
# install(DIRECTORY "tests" DESTINATION .)

# Tell CPack to create a zip file.
set(CPACK_GENERATOR "TGZ")

# Tell CPack what to name the zip file. It will append `.tar.gz`.
set(CPACK_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${VER}")

# Tell CPack not to put everything inside an enclosing directory.
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)

# Apparently this should be always on but isn't for backwards compatibility.
set(CPACK_VERBATIM_VARIABLES YES)

include(CPack)

add_custom_command(
  TARGET bundle
  COMMAND "${CMAKE_COMMAND}" --build . --target package
  WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
  COMMENT "Bundling libBeresta language binding package"
  VERBATIM
)
