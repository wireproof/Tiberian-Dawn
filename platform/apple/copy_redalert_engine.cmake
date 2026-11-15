file(GLOB engine_candidates LIST_DIRECTORIES FALSE
    "${RED_ALERT_ENGINE_ROOT}/${RED_ALERT_CONFIGURATION}-*/libRedAlertEngine.dylib"
    "${RED_ALERT_ENGINE_ROOT}/${RED_ALERT_CONFIGURATION}/libRedAlertEngine.dylib")
list(LENGTH engine_candidates engine_count)
if(NOT engine_count EQUAL 1)
    message(FATAL_ERROR "Expected one Red Alert engine for ${RED_ALERT_CONFIGURATION}; found ${engine_count}")
endif()
file(MAKE_DIRECTORY "${RED_ALERT_APP}/Frameworks")
list(GET engine_candidates 0 engine)
file(COPY_FILE "${engine}" "${RED_ALERT_APP}/Frameworks/RedAlertEngine.dylib" ONLY_IF_DIFFERENT)
