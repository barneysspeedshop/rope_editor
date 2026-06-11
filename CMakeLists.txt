cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "rope_editor")
project(${PROJECT_NAME} LANGUAGES CXX)

# Include the cargokit build logic from the project root
include("../cargokit/cmake/cargokit.cmake")

# Trigger the Rust build for the 'native' crate located in the rust/ directory
apply_cargokit(${PROJECT_NAME} ../rust native "")

# Bundle the resulting shared library (libnative.so) into the Linux application
set(rope_editor_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)