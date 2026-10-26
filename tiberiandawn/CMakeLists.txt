set(TIBDAWN_SRC
    aadata.cpp
    abstract.cpp
    adata.cpp
    aircraft.cpp
    anim.cpp
    audio.cpp
    base.cpp
    bbdata.cpp
    bdata.cpp
    building.cpp
    bullet.cpp
    cargo.cpp
    ccini.cpp
    cdata.cpp
    cell.cpp
    checkbox.cpp
    cheklist.cpp
    colrlist.cpp
    combat.cpp
    confdlg.cpp
    conquer.cpp
    const.cpp
    coord.cpp
    credits.cpp
    debug.cpp
    dial8.cpp
    dialog.cpp
    display.cpp
    door.cpp
    drive.cpp
    drop.cpp
    edit.cpp
    ending.cpp
    event.cpp
    expand.cpp
    facing.cpp
    factory.cpp
    findpath.cpp
    flasher.cpp
    fly.cpp
    foot.cpp
    fuse.cpp
    gamedlg.cpp
    gauge.cpp
    globals.cpp
    goptions.cpp
    gscreen.cpp
    hdata.cpp
    heap.cpp
    help.cpp
    house.cpp
    iconset.cpp
    idata.cpp
    infantry.cpp
    init.cpp
    intro.cpp
    iomap.cpp
    ioobj.cpp
    jshell.cpp
    layer.cpp
    lib.cpp
    list.cpp
    loaddlg.cpp
    logic.cpp
    map.cpp
    mapeddlg.cpp
    mapedit.cpp
    mapedplc.cpp
    mapedsel.cpp
    mapedtm.cpp
    mapsel.cpp
    menus.cpp
    miscasm.cpp
    mission.cpp
    monoc.cpp
    mouse.cpp
    mplayer.cpp
    msgbox.cpp
    msglist.cpp
    nulldlg.cpp
    object.cpp
    odata.cpp
    options.cpp
    overlay.cpp
    power.cpp
    profile.cpp
    queue.cpp
    radar.cpp
    radio.cpp
    reinf.cpp
    rules.cpp
    saveload.cpp
    scenario.cpp
    scenarioini.cpp
    score.cpp
    scroll.cpp
    sdata.cpp
    shapebtn.cpp
    sidebar.cpp
    slider.cpp
    smudge.cpp
    sounddlg.cpp
    special.cpp
    startup.cpp
    stats.cpp
    super.cpp
    tab.cpp
    tarcom.cpp
    target.cpp
    tdata.cpp
    team.cpp
    teamtype.cpp
    techno.cpp
    template.cpp
    terrain.cpp
    textbtn.cpp
    theme.cpp
    trigger.cpp
    turret.cpp
    txtlabel.cpp
    udata.cpp
    unit.cpp
    visudlg.cpp
    winstub.cpp
)

if(IPADOS_PORT)
    list(APPEND TIBDAWN_SRC
        ipados_lifecycle.cpp
        ipados_save_bridge.cpp
        ${CMAKE_SOURCE_DIR}/common/ipados_localization.cpp
        ${CMAKE_SOURCE_DIR}/common/relay_protocol.cpp
        ${CMAKE_SOURCE_DIR}/platform/apple/apple_relay_transport.mm
        ${CMAKE_SOURCE_DIR}/platform/apple/ipados_platform.mm
        ${CMAKE_SOURCE_DIR}/platform/apple/wireproof_orders.mm
        ${CMAKE_SOURCE_DIR}/third_party/unshieldv3/ISArchiveV3.cpp
        ${CMAKE_SOURCE_DIR}/third_party/unshieldv3/blast.c
    )
elseif(VISIONOS_PORT)
    list(APPEND TIBDAWN_SRC
        ipados_lifecycle.cpp
        ipados_save_bridge.cpp
        ${CMAKE_SOURCE_DIR}/common/ipados_localization.cpp
        ${CMAKE_SOURCE_DIR}/common/relay_protocol.cpp
        ${CMAKE_SOURCE_DIR}/platform/apple/apple_relay_transport.mm
        ${CMAKE_SOURCE_DIR}/platform/apple/visionos_platform.mm
        ${CMAKE_SOURCE_DIR}/third_party/unshieldv3/ISArchiveV3.cpp
        ${CMAKE_SOURCE_DIR}/third_party/unshieldv3/blast.c
    )
elseif(MACOS_PORT)
    list(APPEND TIBDAWN_SRC
        ${CMAKE_SOURCE_DIR}/common/ipados_localization.cpp
        ${CMAKE_SOURCE_DIR}/common/relay_protocol.cpp
        ${CMAKE_SOURCE_DIR}/platform/apple/apple_relay_transport.mm
        ${CMAKE_SOURCE_DIR}/platform/apple/macos_platform.mm
        ${CMAKE_SOURCE_DIR}/third_party/unshieldv3/ISArchiveV3.cpp
        ${CMAKE_SOURCE_DIR}/third_party/unshieldv3/blast.c
    )
endif()

if(APPLE_NATIVE_PORT)
    list(APPEND TIBDAWN_SRC ${CMAKE_SOURCE_DIR}/common/wireproof_orders.cpp wireproof_rules.cpp wireproof_viewport.cpp ${CMAKE_SOURCE_DIR}/platform/apple/wireproof_workshop.mm)
    set_source_files_properties(${CMAKE_SOURCE_DIR}/platform/apple/wireproof_workshop.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
    set_source_files_properties(
        ${CMAKE_SOURCE_DIR}/platform/apple/apple_relay_transport.mm
        PROPERTIES COMPILE_FLAGS "-fobjc-arc"
    )
endif()

if(NETWORKING)
    list(APPEND TIBDAWN_NET_SRC
        ipxconn.cpp
        ipxgconn.cpp
        ipxmgr.cpp
        netdlg.cpp
    )
endif()

if(CMAKE_CONFIGURATION_TYPES)
    # Glob all the header files together to add to the project for msvc/xcode.
    # Not ideal as CMake won't notice if you add any until something else prompts a CMake run
    # but this is largely a convenience feature for MSVC/XCode users.
    file(GLOB_RECURSE TIBDAWN_HEADERS "*.h")
    set(_TIBDAWN_SOURCES ${TIBDAWN_SRC})

    foreach(_TIBDAWN_SOURCE IN ITEMS ${_TIBDAWN_SOURCES})
        get_filename_component(_TIBDAWN_SOURCE_PATH "${_TIBDAWN_SOURCE}" PATH)
        string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}" "" _TIBDAWN_GROUP_PATH "${_TIBDAWN_SOURCE_PATH}")
        string(REPLACE "/" "\\" _TIBDAWN_GROUP_PATH "${_TIBDAWN_GROUP_PATH}")
        source_group("Source Files\\${_TIBDAWN_GROUP_PATH}" FILES "${_TIBDAWN_SOURCE}")
    endforeach()

    foreach(_TIBDAWN_HEADER IN ITEMS ${TIBDAWN_HEADERS})
        get_filename_component(_TIBDAWN_HEADER_PATH "${_TIBDAWN_HEADER}" PATH)
        string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}" "" _TIBDAWN_HGROUP_PATH "${_TIBDAWN_HEADER_PATH}")
        string(REPLACE "/" "\\" _TIBDAWN_HGROUP_PATH "${_TIBDAWN_HGROUP_PATH}")
        source_group("Header Files\\${_TIBDAWN_HGROUP_PATH}" FILES "${_TIBDAWN_HEADER}")
    endforeach()
endif()

include(ProductVersion)

if(BUILD_REMASTERTD)
    if(WIN32 OR CMAKE_SYSTEM_NAME STREQUAL "Windows")
        # Generate windows version info.
        generate_product_version(
            REMASTERTD_RC
            NAME "Vanilla Conquer TiberianDawn DLL"
            BUNDLE "Vanilla Conquer"
            VERSION_MAJOR 1
            VERSION_MINOR 7
            COMPANY_NAME "Vanilla Conquer"
            COMPANY_COPYRIGHT "Based on code released under GPLv3 by EA"
            ORIGINAL_FILENAME "TiberianDawn.dll"
            RCFILE_PREFIX "RemasterTD"
        )
    endif()
    add_library(TiberianDawn SHARED 
        dllinterface.cpp
        dllinterfaceeditor.cpp
        sidebarglyphx.cpp
        ${TIBDAWN_SRC}
        ${TIBDAWN_HEADERS}
        ${REMASTERTD_RC}
    )
    target_compile_definitions(TiberianDawn PUBLIC $<$<CONFIG:Debug>:_DEBUG> ${REMASTER_DEFS} MEGAMAPS)
    target_include_directories(TiberianDawn PUBLIC ${CMAKE_SOURCE_DIR} .)
    target_link_libraries(TiberianDawn commonr ${REMASTER_LIBS} ${STATIC_LIBS})
    set_target_properties(TiberianDawn PROPERTIES PREFIX "")

    add_custom_command(TARGET TiberianDawn POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/resources/remaster_mods/Vanilla_TD ${CMAKE_BINARY_DIR}/Vanilla_TD
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/Vanilla_TD/Data
        COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:TiberianDawn> ${CMAKE_BINARY_DIR}/Vanilla_TD/Data/
    )
endif()

if(BUILD_VANILLATD)
    include(BuildIcons)
    # Create the custom command for generating the ico/icns files for display in the OS.
    make_icon(INPUT "${CMAKE_SOURCE_DIR}/resources/vanillatd_icon.svg" OUTPUT VANILLATD_ICON)

    if(WIN32 OR CMAKE_SYSTEM_NAME STREQUAL "Windows")
        # Generate windows version info.
        generate_product_version(
            VANILLATD_RC
            NAME "Tiberian Dawn for iPad"
            BUNDLE "Tiberian Dawn for iPad"
            VERSION_MAJOR 1
            VERSION_MINOR 0
            COMPANY_NAME "Tiberian Dawn for iPad contributors"
            COMPANY_COPYRIGHT "Based on code released under GPLv3 by EA"
            ORIGINAL_FILENAME "tiberiandawn.exe"
            RCFILE_PREFIX "TiberianDawn"
            ICON "${VANILLATD_ICON}"
        )
    endif()

    # A target must include the icon for the custom command to run.
    add_executable(TiberianDawn ${TIBDAWN_SRC} ${TIBDAWN_NET_SRC} ${TIBDAWN_HEADERS} ${VANILLATD_RC} ${VANILLATD_ICON})

    if(MAKE_BUNDLE)
        set_source_files_properties(${VANILLATD_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        set_target_properties(TiberianDawn PROPERTIES
            MACOSX_BUNDLE True
            MACOSX_BUNDLE_GUI_IDENTIFIER com.wireproof.tiberiandawn
            MACOSX_BUNDLE_BUNDLE_NAME "Tiberian Dawn"
            MACOSX_BUNDLE_BUNDLE_VERSION "${TIBERIAN_DAWN_BUILD_VERSION}"
            MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
            MACOSX_BUNDLE_COPYRIGHT "Based on code released under GPLv3 by EA"
            MACOSX_BUNDLE_ICON_FILE "vanillatd_icon.icns"
        )

        if(IPADOS_PORT)
            # SDL's UIKit application delegate owns the real process entry
            # point and calls the game's entry as SDL_main.
            set_source_files_properties(startup.cpp PROPERTIES COMPILE_DEFINITIONS "main=SDL_main")
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/Assets.xcassets
                ${CMAKE_SOURCE_DIR}/platform/apple/PrivacyInfo.xcprivacy
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/manifest.ini
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/ui/cursor-default.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/ui
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/buggy/buggy-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/buggy
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/humvee/humvee-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/humvee
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/minigunner/minigunner-atlas-4x-v2.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/minigunner
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/gdi-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/nod-mcv-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/mcv
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-activity-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-activity-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/infrastructure
            )
            target_sources(TiberianDawn PRIVATE
                ${CMAKE_SOURCE_DIR}/resources/apple/Assets.xcassets
                ${CMAKE_SOURCE_DIR}/platform/apple/PrivacyInfo.xcprivacy
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/manifest.ini
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/ui/cursor-default.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/buggy/buggy-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/humvee/humvee-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/minigunner/minigunner-atlas-4x-v2.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/gdi-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/nod-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-activity-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-activity-atlas-4x.png
            )
            set_target_properties(TiberianDawn PROPERTIES
                MACOSX_BUNDLE_GUI_IDENTIFIER "${IPADOS_BUNDLE_IDENTIFIER}"
                MACOSX_BUNDLE_BUNDLE_NAME "Tiberian Dawn for iPad"
                MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/platform/apple/Info-iPadOS.plist.in"
                XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${IPADOS_BUNDLE_IDENTIFIER}"
                XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
                XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST "NO"
                XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
                XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES "AppIconGDI AppIconNod"
                XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
                XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
            )
            target_link_libraries(TiberianDawn "-framework UIKit" "-framework AVFAudio" "-framework Metal" "-framework MetalKit" "-framework QuartzCore" "-framework UniformTypeIdentifiers")
            if(IPADOS_DEVELOPMENT_TEAM)
                set_target_properties(TiberianDawn PROPERTIES
                    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${IPADOS_DEVELOPMENT_TEAM}"
                    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
                    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "YES"
                    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "YES"
                )
            endif()
        elseif(VISIONOS_PORT)
            # SDL's UIKit entry point remains the application entry for the
            # native windowed visionOS prototype.
            set_source_files_properties(startup.cpp PROPERTIES COMPILE_DEFINITIONS "main=SDL_main")
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/visionos/Assets.xcassets
                ${CMAKE_SOURCE_DIR}/platform/apple/PrivacyInfo.xcprivacy
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/manifest.ini
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/ui/cursor-default.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/ui
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/buggy/buggy-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/buggy
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/humvee/humvee-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/humvee
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/minigunner/minigunner-atlas-4x-v2.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/minigunner
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/gdi-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/nod-mcv-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/mcv
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-activity-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-activity-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/infrastructure
            )
            target_sources(TiberianDawn PRIVATE
                ${CMAKE_SOURCE_DIR}/resources/visionos/Assets.xcassets
                ${CMAKE_SOURCE_DIR}/platform/apple/PrivacyInfo.xcprivacy
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/manifest.ini
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/ui/cursor-default.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/buggy/buggy-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/humvee/humvee-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/minigunner/minigunner-atlas-4x-v2.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/gdi-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/nod-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-activity-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-activity-atlas-4x.png
            )
            set_target_properties(TiberianDawn PROPERTIES
                MACOSX_BUNDLE_GUI_IDENTIFIER "${VISIONOS_BUNDLE_IDENTIFIER}"
                MACOSX_BUNDLE_BUNDLE_NAME "Tiberian Dawn for Vision Pro"
                MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/platform/apple/Info-visionOS.plist.in"
                XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${VISIONOS_BUNDLE_IDENTIFIER}"
                XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
                XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
            )
            target_link_libraries(TiberianDawn "-framework UIKit" "-framework AVFAudio" "-framework Metal" "-framework MetalKit" "-framework QuartzCore" "-framework UniformTypeIdentifiers")
            if(VISIONOS_DEVELOPMENT_TEAM)
                set_target_properties(TiberianDawn PROPERTIES
                    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${VISIONOS_DEVELOPMENT_TEAM}"
                    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
                    # The shared visionOS preset disables signing globally so
                    # CI can compile static dependencies without credentials.
                    # Re-enable it only for the installable application when
                    # a local development team was supplied.
                    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "YES"
                    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "YES"
                )
            endif()
        elseif(MACOS_PORT)
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/Assets.xcassets
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/manifest.ini
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/ui/cursor-default.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/ui
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/buggy/buggy-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/buggy
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/humvee/humvee-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/humvee
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/minigunner/minigunner-atlas-4x-v2.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/minigunner
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/gdi-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/nod-mcv-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/mcv
            )
            set_source_files_properties(
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-activity-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-activity-atlas-4x.png
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ModernArt/units/infrastructure
            )
            target_sources(TiberianDawn PRIVATE
                ${CMAKE_SOURCE_DIR}/resources/apple/Assets.xcassets
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/manifest.ini
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/ui/cursor-default.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/buggy/buggy-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/humvee/humvee-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/minigunner/minigunner-atlas-4x-v2.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/gdi-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/mcv/nod-mcv-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/gdi-infrastructure-activity-atlas-4x.png
                ${CMAKE_SOURCE_DIR}/resources/apple/ModernArt/units/infrastructure/nod-infrastructure-activity-atlas-4x.png
            )
            set_target_properties(TiberianDawn PROPERTIES
                MACOSX_BUNDLE_GUI_IDENTIFIER "com.wireproof.tiberiandawn"
                MACOSX_BUNDLE_BUNDLE_NAME "Tiberian Dawn"
                MACOSX_BUNDLE_ICON_FILE "AppIcon.icns"
                MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/platform/apple/Info-macOS.plist.in"
                XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.wireproof.tiberiandawn"
                XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
            )
            target_link_libraries(TiberianDawn "-framework AppKit" "-framework AVFAudio" "-framework Metal" "-framework MetalKit" "-framework QuartzCore" "-framework UniformTypeIdentifiers")
        endif()
    endif()

    target_compile_definitions(TiberianDawn PUBLIC $<$<CONFIG:Debug>:_DEBUG> ${VANILLA_DEFS} MEGAMAPS)
    target_include_directories(TiberianDawn PUBLIC ${CMAKE_SOURCE_DIR} .)
    target_link_libraries(TiberianDawn commonv ${VANILLA_LIBS} ${STATIC_LIBS})
    if(MACOS_PORT)
        set_target_properties(TiberianDawn PROPERTIES OUTPUT_NAME "Tiberian Dawn")
    else()
        set_target_properties(TiberianDawn PROPERTIES OUTPUT_NAME TiberianDawn)
    endif()
    if(MAP_EDITORTD)
        target_compile_definitions(TiberianDawn PUBLIC INTERNAL_VERSION)
    endif()
    # Control if we auto generate a console and which "main" function we link using MSVC.
    if(MSVC)
        target_link_options(TiberianDawn PRIVATE /subsystem:windows /ENTRY:mainCRTStartup)
    endif()
    if(WIN32 AND NOT MSVC)
        set_target_properties(TiberianDawn PROPERTIES LINK_FLAGS "-mwindows")
    endif()
    if(BUILD_WITH_UBSAN)
        target_compile_options(TiberianDawn PUBLIC
                    -fsanitize=undefined,float-divide-by-zero,integer,implicit-conversion,implicit-integer-truncation,implicit-integer-arithmetic-value-change,local-bounds,nullability
                    -g3 -fno-omit-frame-pointer)
        target_link_options(TiberianDawn PUBLIC -fsanitize=undefined,float-divide-by-zero,integer,implicit-conversion,implicit-integer-truncation,implicit-integer-arithmetic-value-change,local-bounds,nullability)
    endif()
    if(BUILD_WITH_ASAN)
        target_compile_options(TiberianDawn PUBLIC
                    -fsanitize=address
                    -g3 -fno-omit-frame-pointer)
        target_link_options(TiberianDawn PUBLIC -fsanitize=address)
    endif()
endif()

if(TARGET TiberianDawn AND (IPADOS_PORT OR MACOS_PORT OR VISIONOS_PORT OR CMAKE_SYSTEM_NAME STREQUAL "iOS"))
    target_compile_definitions(TiberianDawn PRIVATE WIREPROOF_APP_VERSION="${PROJECT_VERSION}")
endif()

if(IPADOS_PORT)
set_source_files_properties(${CMAKE_SOURCE_DIR}/platform/apple/wireproof_orders.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
endif()
