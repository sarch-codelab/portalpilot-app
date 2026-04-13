# This file is part of the Flutter SDK.
# See https://flutter.dev for more information.

cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Get the Flutter engine and application data.
include("${EPHEMERAL_DIR}/generated_config.cmake")
include("${EPHEMERAL_DIR}/generated_plugins.cmake")

# Set the Flutter tool binary location.
set(FLUTTER_TOOL "${FLUTTER_ROOT}/bin/flutter")
string(REGEX REPLACE "/" "\\\\" FLUTTER_TOOL_WIN "${FLUTTER_TOOL}")

# Add the Flutter library.
add_library(Flutter INTERFACE)
target_include_directories(Flutter INTERFACE
  "${EPHEMERAL_DIR}/cpp_client_wrapper/include"
)
target_link_libraries(Flutter INTERFACE
  "${EPHEMERAL_DIR}/flutter_windows.dll.lib"
)
