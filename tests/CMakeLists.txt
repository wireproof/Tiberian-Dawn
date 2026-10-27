add_custom_target(tests)
add_dependencies(tests test_remastered_scene test_miscasm test_face test_rect test_fading test_lcw test_xordelta test_irandom test_fatpixel test_tobuff test_drawline test_putpixel test_drawbuff test_ipados_layout test_ipados_localization test_ipados_pencil test_audio_queue_state test_app_lifecycle test_recovery_transaction test_install_transaction test_iso9660 test_isarchivev3 test_savegame_transfer test_hd_asset_pack test_relay_protocol test_visionos_input)

add_executable(test_ipados_pencil ipados_pencil.cpp ../common/ipados_pencil.cpp)
target_include_directories(test_ipados_pencil PUBLIC .. ../common)
add_test(NAME ipados_pencil COMMAND $<TARGET_FILE:test_ipados_pencil>)

add_executable(test_visionos_input visionos_input.cpp ../common/visionos_input.cpp)
target_include_directories(test_visionos_input PUBLIC .. ../common)
add_test(NAME visionos_input COMMAND $<TARGET_FILE:test_visionos_input>)

add_executable(test_relay_protocol relay_protocol.cpp ../common/relay_protocol.cpp)
target_include_directories(test_relay_protocol PUBLIC .. ../common)
add_test(NAME relay_protocol COMMAND $<TARGET_FILE:test_relay_protocol>)

add_executable(test_ipados_layout ipados_layout.cpp ../common/ipados_layout.cpp)
target_include_directories(test_ipados_layout PUBLIC .. ../common)
add_test(NAME ipados_layout COMMAND $<TARGET_FILE:test_ipados_layout>)

add_executable(test_ipados_localization ipados_localization.cpp ../common/ipados_localization.cpp)
target_include_directories(test_ipados_localization PUBLIC .. ../common)
add_test(NAME ipados_localization COMMAND $<TARGET_FILE:test_ipados_localization>)

add_executable(test_hd_asset_pack hd_asset_pack.cpp ../common/hd_asset_pack.cpp)
target_include_directories(test_hd_asset_pack PUBLIC .. ../common)
add_test(NAME hd_asset_pack COMMAND $<TARGET_FILE:test_hd_asset_pack>)

add_executable(test_audio_queue_state audio_queue_state.cpp ../common/audio_queue_state.cpp)
target_include_directories(test_audio_queue_state PUBLIC .. ../common)
add_test(NAME audio_queue_state COMMAND $<TARGET_FILE:test_audio_queue_state>)

add_executable(test_app_lifecycle app_lifecycle.cpp ../common/app_lifecycle.cpp)
target_include_directories(test_app_lifecycle PUBLIC .. ../common)
add_test(NAME app_lifecycle COMMAND $<TARGET_FILE:test_app_lifecycle>)

add_executable(test_recovery_transaction recovery_transaction.cpp ../common/recovery_transaction.cpp)
target_include_directories(test_recovery_transaction PUBLIC .. ../common)
add_test(NAME recovery_transaction COMMAND $<TARGET_FILE:test_recovery_transaction>)

add_executable(test_install_transaction install_transaction.cpp ../common/install_transaction.cpp)
target_include_directories(test_install_transaction PUBLIC .. ../common)
add_test(NAME install_transaction COMMAND $<TARGET_FILE:test_install_transaction>)

add_executable(test_iso9660 iso9660.cpp ../common/iso9660.cpp)
target_include_directories(test_iso9660 PUBLIC .. ../common)
add_test(NAME iso9660 COMMAND $<TARGET_FILE:test_iso9660>)

add_executable(test_isarchivev3 isarchivev3.cpp ../third_party/unshieldv3/ISArchiveV3.cpp ../third_party/unshieldv3/blast.c)
target_include_directories(test_isarchivev3 PUBLIC .. ../third_party/unshieldv3)
add_test(NAME isarchivev3 COMMAND $<TARGET_FILE:test_isarchivev3>)

add_executable(test_savegame_transfer savegame_transfer.cpp ../common/savegame_transfer.cpp)
target_include_directories(test_savegame_transfer PUBLIC .. ../common)
add_test(NAME savegame_transfer COMMAND $<TARGET_FILE:test_savegame_transfer>)

add_executable(test_miscasm miscasm.cpp)
target_include_directories(test_miscasm PUBLIC .. ../common)
target_compile_definitions(test_miscasm PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_miscasm PUBLIC common ${STATIC_LIBS})
add_test(NAME miscasm COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_miscasm>)

add_executable(test_face face.cpp)
target_include_directories(test_face PUBLIC .. ../common)
target_compile_definitions(test_face PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_face PUBLIC common ${STATIC_LIBS})
add_test(NAME face COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_face>)

add_executable(test_rect rect.cpp)
target_include_directories(test_rect PUBLIC .. ../common)
target_compile_definitions(test_rect PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_rect PUBLIC common ${STATIC_LIBS})
add_test(NAME rect COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_rect>)

add_executable(test_fading fading.cpp)
target_include_directories(test_fading PUBLIC .. ../common)
target_compile_definitions(test_fading PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_fading PUBLIC common ${STATIC_LIBS})
add_test(NAME fading COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_fading>)

add_executable(test_lcw lcw.cpp)
target_include_directories(test_lcw PUBLIC .. ../common)
target_compile_definitions(test_lcw PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_lcw PUBLIC common ${STATIC_LIBS})
add_test(NAME lcw COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_lcw>)

add_executable(test_xordelta xordelta.cpp)
target_include_directories(test_xordelta PUBLIC .. ../common)
target_compile_definitions(test_xordelta PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_xordelta PUBLIC common ${STATIC_LIBS})
add_test(NAME xordelta COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_xordelta>)

add_executable(test_irandom irandom.cpp)
target_include_directories(test_irandom PUBLIC .. ../common)
target_compile_definitions(test_irandom PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_irandom PUBLIC common ${STATIC_LIBS})
add_test(NAME irandom COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_irandom>)

add_executable(test_fatpixel fatpixel.cpp)
target_include_directories(test_fatpixel PUBLIC .. ../common)
target_compile_definitions(test_fatpixel PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_fatpixel PUBLIC commonv ${STATIC_LIBS})
add_test(NAME fatpixel COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_fatpixel>)

add_executable(test_tobuff tobuff.cpp)
target_include_directories(test_tobuff PUBLIC .. ../common)
target_compile_definitions(test_tobuff PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_tobuff PUBLIC commonv ${STATIC_LIBS})
add_test(NAME tobuff COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_tobuff>)

add_executable(test_drawline drawline.cpp)
target_include_directories(test_drawline PUBLIC .. ../common)
target_compile_definitions(test_drawline PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_drawline PUBLIC commonv ${STATIC_LIBS})
add_test(NAME drawline COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_drawline>)

add_executable(test_putpixel putpixel.cpp)
target_include_directories(test_putpixel PUBLIC .. ../common)
target_compile_definitions(test_putpixel PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_putpixel PUBLIC commonv ${STATIC_LIBS})
add_test(NAME putpixel COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_putpixel>)

add_executable(test_drawbuff drawbuff.cpp)
target_include_directories(test_drawbuff PUBLIC .. ../common)
target_compile_definitions(test_drawbuff PUBLIC TRUE_FALSE_DEFINED ENGLISH $<$<CONFIG:DEBUG>:_DEBUG> _WINDOWS _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE WINSOCK_IPX)
target_link_libraries(test_drawbuff PUBLIC commonv ${STATIC_LIBS})
add_test(NAME drawbuff COMMAND ${TARGET_SYSTEM_EMULATOR} $<TARGET_FILE:test_drawbuff>)

add_executable(test_wireproof_orders wireproof_orders.cpp ../common/wireproof_orders.cpp)
target_include_directories(test_wireproof_orders PUBLIC ..)
add_dependencies(tests test_wireproof_orders)
add_test(NAME wireproof_orders COMMAND $<TARGET_FILE:test_wireproof_orders>)

add_executable(test_remastered_scene remastered_scene.cpp ../common/remastered_scene.cpp)
target_include_directories(test_remastered_scene PUBLIC .. ../common)
add_test(NAME remastered_scene COMMAND $<TARGET_FILE:test_remastered_scene>)
