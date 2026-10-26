cmake_minimum_required(VERSION 3.25)

if(CMAKE_SYSTEM_NAME STREQUAL "visionOS" AND CMAKE_VERSION VERSION_LESS 3.28)
    message(FATAL_ERROR "The native visionOS target requires CMake 3.28 or newer.")
endif()

# Allow passing search paths from environment.
foreach(_path_elem $ENV{CMAKE_FIND_ROOT_PATH})
    if(NOT IS_ABSOLUTE ${_path_elem})
        list(APPEND CMAKE_FIND_ROOT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${_path_elem}")
    else()     
        list(APPEND CMAKE_FIND_ROOT_PATH "${_path_elem}")
    endif()
endforeach()

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/")
include(FeatureSummary)
include(CheckCXXCompilerFlag)

if(NOT DEFINED CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "Choose the type of build, options are: Debug Release RelWithDebInfo" FORCE)
endif()

project(TiberianDawnApple VERSION 0.5.2 LANGUAGES C CXX)

# All native Apple applications use the same public version and monotonically
# increasing build number. Keep these values centralized so macOS, iPadOS,
# local builds, and distributed releases cannot silently drift apart.
set(TIBERIAN_DAWN_BUILD_VERSION "502")

option(BUILD_REMASTERTD "Build Tiberian Dawn remaster dll." OFF)
option(BUILD_REMASTERRA "Build Red Alert remaster dll." OFF)
option(BUILD_VANILLATD "Build Tiberian Dawn executable." ON)
option(BUILD_VANILLARA "Build Red Alert executable." ON)
option(MAP_EDITORTD "Include internal scenario editor in Tiberian Dawn build." OFF)
option(MAP_EDITORRA "Include internal scenario editor in Red Alert build." OFF)
option(NETWORKING "Enable network play." ON)
option(WIN9X "Enable support for Windows 95/98/ME." OFF)
option(DSOUND "Enable DirectSound audio. (deprecated)" OFF)
option(DDRAW "Enable DirectDraw video backend. (deprecated)" OFF)
option(SDL1 "Enable SDL1 video backend." OFF)
option(SDL2 "Enable SDL2 video backend." ON)
option(OPENAL "Enable OpenAL audio backend." ON)
option(BUILD_TESTS "Build unit tests." OFF)
option(BUILD_TOOLS "Build modding utilities." OFF)
option(BUILD_WITH_UBSAN "Build with undefined behavior sanitizer" OFF)
option(BUILD_WITH_ASAN "Build with address sanitizer" OFF)
option(GERMAN "Use German instead of English." OFF)
option(FRENCH "Use French instead of English." OFF)
option(MACOS_PORT "Build the self-contained native macOS application." OFF)

# The iPadOS port vendors SDL2 so device and simulator builds never link the
# Homebrew/macOS binary by accident.
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    option(IPADOS_PORT "Build the iPadOS port." ON)
else()
    option(IPADOS_PORT "Build the iPadOS port." OFF)
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "visionOS")
    option(VISIONOS_PORT "Build the native visionOS prototype." ON)
else()
    option(VISIONOS_PORT "Build the native visionOS prototype." OFF)
endif()
set(IPADOS_BUNDLE_IDENTIFIER "org.tiberiandawn.ipad" CACHE STRING "Bundle identifier for the iPadOS application")
set(IPADOS_DEVELOPMENT_TEAM "" CACHE STRING "Apple development team used to sign the iPadOS application")
set(VISIONOS_BUNDLE_IDENTIFIER "org.tiberiandawn.visionos" CACHE STRING "Bundle identifier for the visionOS application")
set(VISIONOS_DEVELOPMENT_TEAM "" CACHE STRING "Apple development team used to sign the visionOS application")

if((IPADOS_PORT AND MACOS_PORT) OR (IPADOS_PORT AND VISIONOS_PORT) OR (MACOS_PORT AND VISIONOS_PORT))
    message(FATAL_ERROR "IPADOS_PORT, MACOS_PORT, and VISIONOS_PORT are mutually exclusive.")
endif()

set(APPLE_NATIVE_PORT OFF)
if(IPADOS_PORT OR MACOS_PORT OR VISIONOS_PORT)
    set(APPLE_NATIVE_PORT ON)
endif()
set(APPLE_UIKIT_PORT OFF)
if(IPADOS_PORT OR VISIONOS_PORT)
    set(APPLE_UIKIT_PORT ON)
endif()

if(MACOS_PORT AND (NOT APPLE OR CMAKE_SYSTEM_NAME STREQUAL "iOS"))
    message(FATAL_ERROR "MACOS_PORT is available only for native macOS builds.")
endif()
if(VISIONOS_PORT AND NOT CMAKE_SYSTEM_NAME STREQUAL "visionOS")
    message(FATAL_ERROR "VISIONOS_PORT requires CMAKE_SYSTEM_NAME=visionOS.")
endif()

# Both native Apple targets use the same AVAudioEngine backend. Keeping this
# decision here prevents a platform preset from silently falling back to the
# legacy OpenAL path.
if(APPLE_NATIVE_PORT)
    set(OPENAL OFF CACHE BOOL "OpenAL is replaced by AVAudioEngine on Apple ports" FORCE)
endif()

if(WIN32 OR CMAKE_SYSTEM_NAME STREQUAL "Windows")
    option(WIN9X "Enable support for Windows 95/98/ME." OFF)
    option(DSOUND "Enable DirectSound audio. (deprecated)" OFF)
    option(DDRAW "Enable DirectDraw video backend. (deprecated)" OFF)
    add_feature_info(Windows9x WIN9X "Windows 95/98/ME support" OFF)
    add_feature_info(DirectSound DSOUND "DirectSound audio backend (deprecated)")
    add_feature_info(DirectDraw DDRAW "DirectDraw video backend (deprecated)")
endif()

if(APPLE OR ${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    option(MAKE_BUNDLE "Create a standard app bundle rather than command line program." ON)   
    add_feature_info(MakeBundle MAKE_BUNDLE "App bundles will be generated")
    if(MAKE_BUNDLE)
        set(MAKE_BUNDLE_OPTION MACOSX_BUNDLE)
    endif()
endif()

add_feature_info(SDL1 SDL1 "SDL1 video backend")
add_feature_info(SDL2 SDL2 "SDL2 video backend")
add_feature_info(OpenAL OPENAL "OpenAL audio backend")
add_feature_info(macOSPort MACOS_PORT "Self-contained native macOS application")
add_feature_info(visionOSPort VISIONOS_PORT "Native visionOS prototype")
add_feature_info(RemasterTD BUILD_REMASTERTD, "Remastered Tiberian Dawn dll")
add_feature_info(RemasterRA BUILD_REMASTERRA "Remastered Red Alert dll")
add_feature_info(TiberianDawn BUILD_VANILLATD "Tiberian Dawn executable")
add_feature_info(VanillaRA BUILD_VANILLARA "Red Alert executable")
add_feature_info(MapEditorTD MAP_EDITORTD "Include internal scenario editor in TiberianDawn")
add_feature_info(MapEditorRA MAP_EDITORRA "Include internal scenario editor in VanillaRA")
add_feature_info(Networking NETWORKING "Networking support")
add_feature_info(Tests BUILD_TESTS "Unit tests")
add_feature_info(Tools BUILD_TOOLS "Mod developer tools")

if(NOT BUILD_VANILLATD AND NOT BUILD_VANILLARA AND NOT BUILD_TESTS)
    set(DSOUND OFF)
    set(DDRAW OFF)
    set(SDL1 OFF)
    set(SDL2 OFF)
    set(OPENAL OFF)
endif()

if(NOT DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
endif()

include(Compilers)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_FIND_FRAMEWORK "LAST")

add_definitions(-DTRUE_FALSE_DEFINED)

if(GERMAN)
    add_definitions(-DGERMAN)
elseif(FRENCH)
    add_definitions(-DFRENCH)
else()
    add_definitions(-DENGLISH)
endif()

if(WIN32)
    add_definitions(-DWIN32 -D_WINDOWS -D_CRT_SECURE_NO_DEPRECATE -D_CRT_NONSTDC_NO_DEPRECATE -DNOMINMAX)
    set(COMMON_LIBS winmm)
endif()

set(VANILLA_DEFS "")
set(VANILLA_LIBS "")

set(REMASTER_DEFS _USRDLL REMASTER_BUILD)
set(REMASTER_LIBS "")

find_package(ClangFormat)
include(ClangFormat)

if(NOT BUILD_VANILLATD AND MAP_EDITORTD)
    message(WARNING "Internal scenario editor requires a Tiberian Dawn executable to be built, but it was not enabled.")
    set(BUILD_VANILLATD TRUE)
endif()

if(NOT BUILD_VANILLARA AND MAP_EDITORRA)
    message(WARNING "Internal scenario editor requires a Red Alert executable to be built, but it is not enabled.")
    set(BUILD_VANILLARA TRUE)
endif()

if(NETWORKING)
    list(APPEND VANILLA_DEFS NETWORKING)
    if(WIN32)
        list(APPEND VANILLA_LIBS ws2_32)
    endif()
endif()

if(SDL1)
    find_package(SDL REQUIRED)
    list(APPEND VANILLA_LIBS ${SDL_LIBRARY})
    include_directories(${SDL_INCLUDE_DIR})

    # winuser.h defines VK_ macros but it can be prevented
    if(WIN32)
        add_definitions(-DNOVIRTUALKEYCODES)
    endif()
    set(DDRAW OFF)
    set(SDL2 OFF)
endif()

if(SDL2)
    if(APPLE_NATIVE_PORT)
        set(SDL_SHARED OFF CACHE BOOL "Build SDL as a shared library" FORCE)
        set(SDL_STATIC ON CACHE BOOL "Build SDL as a static library" FORCE)
        set(SDL_TEST OFF CACHE BOOL "Build the SDL test suite" FORCE)
        set(SDL_TESTS OFF CACHE BOOL "Build the SDL test suite" FORCE)
        set(SDL_INSTALL OFF CACHE BOOL "Install SDL" FORCE)
        set(SDL_DISABLE_INSTALL ON CACHE BOOL "Disable SDL installation rules" FORCE)
        if(MACOS_PORT)
            set(SDL2_DISABLE_SDL2MAIN ON CACHE BOOL "The project supplies its own desktop main function" FORCE)
        endif()
        # Xcode 26 no longer exposes the legacy OSAtomic API to iOS apps.
        # Clang's supported atomic builtins are available on every target.
        set(SDL_GCC_ATOMICS ON CACHE BOOL "Use compiler atomic builtins" FORCE)
        set(HAVE_GCC_ATOMICS 1 CACHE INTERNAL "Clang atomic builtins" FORCE)
        # UIKit's SDL entry point is compiled as C and needs the SDK's
        # stdint/stdlib declarations. Keep SDL on the system C library.
        set(SDL_LIBC ON CACHE BOOL "Use the system C library" FORCE)
        if(VISIONOS_PORT)
            # OpenGL ES/EAGL is unavailable on visionOS.  The native port uses
            # SDL's Metal renderer exclusively; keep the iPad and macOS
            # backends unchanged.
            set(SDL_OPENGL OFF CACHE BOOL "Include OpenGL support" FORCE)
            set(SDL_OPENGLES OFF CACHE BOOL "Include OpenGL ES support" FORCE)
            # visionOS does not expose the low-level HID transport used by
            # SDL's HIDAPI backend. GameController support remains enabled.
            set(SDL_HIDAPI OFF CACHE BOOL "Enable SDL HIDAPI support" FORCE)
            set(SDL_HIDAPI_JOYSTICK OFF CACHE BOOL "Use HIDAPI for joysticks" FORCE)
        endif()
        add_subdirectory(third_party/SDL2 EXCLUDE_FROM_ALL)
        if(APPLE_UIKIT_PORT)
            list(APPEND VANILLA_LIBS SDL2::SDL2main SDL2::SDL2-static)
        else()
            list(APPEND VANILLA_LIBS SDL2::SDL2-static)
        endif()
        include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party/SDL2/include)
        if(IPADOS_PORT)
            list(APPEND VANILLA_DEFS IPADOS_PORT)
        elseif(VISIONOS_PORT)
            # The native prototype deliberately reuses the mature UIKit/touch
            # layer while exposing VISIONOS_PORT for platform-specific growth.
            list(APPEND VANILLA_DEFS IPADOS_PORT VISIONOS_PORT)
        else()
            list(APPEND VANILLA_DEFS MACOS_PORT)
        endif()
    else()
        message("Find path is ${CMAKE_FIND_ROOT_PATH}")
        find_package(SDL2 REQUIRED)
        list(APPEND VANILLA_LIBS ${SDL2_LIBRARY})
        include_directories(${SDL2_INCLUDE_DIR})
    endif()

    # winuser.h defines VK_ macros but it can be prevented
    if(WIN32)
        add_definitions(-DNOVIRTUALKEYCODES)
    endif()
    set(DDRAW OFF)
endif()

if(OPENAL)
    find_package(OpenAL REQUIRED)
    list(APPEND VANILLA_LIBS OpenAL::OpenAL)
    set(DSOUND OFF)
endif()

if(BUILD_TESTS)
    # Tests need to respect some options so need to occur after the options are set.
    enable_testing()
    add_subdirectory(tests)
endif()

add_subdirectory(common)
add_subdirectory(tiberiandawn)
add_subdirectory(redalert)
add_subdirectory(tools)

feature_summary(WHAT ENABLED_FEATURES DESCRIPTION "Enabled features:")
feature_summary(WHAT DISABLED_FEATURES DESCRIPTION "Disabled features:")
