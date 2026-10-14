# ============================================================================
#  CMakeLists.txt — builds the Warforz Vault SILVER token with eosio.cdt / cdt.
#
#  Build from the command line:
#     mkdir build && cd build
#     cmake ..            # finds the cdt package
#     make                # produces warforzvault.wasm + warforzvault.abi
#
#  In EOS Studio: open this folder as a project; EOS Studio detects the
#  CMake target and lets you Build → Deploy from its UI (or just point it at
#  src/warforzvault.cpp with include/ on the include path).
# ============================================================================
cmake_minimum_required(VERSION 3.5)
project(warforzvault)

# eosio.cdt renamed its CMake package to "cdt" in newer versions; try both.
find_package(cdt QUIET)
if(NOT cdt_FOUND)
    find_package(eosio.cdt REQUIRED)
endif()

# Declare the contract target: <target> <contract-name> <source(s)>.
# "warforzvault" is exactly 12 characters of [a-z], so it is a valid WAX account
# name and is used as-is for the contract account. The contract name should
# match the account you deploy to for the ABI to load cleanly — if you deploy
# somewhere else, change it here AND rename the `CONTRACT warforzvault` class in
# include/warforzvault.hpp to match.
add_contract(warforzvault warforzvault ${CMAKE_SOURCE_DIR}/src/warforzvault.cpp)

# Make the headers in include/ visible to the compiler.
target_include_directories(warforzvault PUBLIC ${CMAKE_SOURCE_DIR}/include)

# Optional: enable extra warnings while developing.
target_compile_options(warforzvault PUBLIC -Wall)
