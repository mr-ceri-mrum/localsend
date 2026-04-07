# Bundles FFmpeg (BtbN win64 GPL build) next to the executable for iOS→Windows conversion.
# On first configure, downloads and caches ffmpeg.exe under CMAKE_BINARY_DIR.
# Offline builds: place ffmpeg.exe at windows/ffmpeg/ffmpeg.exe (see README in that folder).

set(_FFMPEG_MANUAL "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/ffmpeg.exe")
set(_FFMPEG_CACHE "${CMAKE_BINARY_DIR}/cached_ffmpeg.exe")

if(EXISTS "${_FFMPEG_MANUAL}")
  set(_FFMPEG_BUNDLE "${_FFMPEG_MANUAL}")
  message(STATUS "Using manually placed FFmpeg: ${_FFMPEG_MANUAL}")
elseif(EXISTS "${_FFMPEG_CACHE}")
  set(_FFMPEG_BUNDLE "${_FFMPEG_CACHE}")
  message(STATUS "Using cached FFmpeg bundle")
else()
  message(STATUS "Downloading FFmpeg Windows x64 bundle (BtbN, GPL) — may take a minute...")
  set(_FF_ZIP "${CMAKE_BINARY_DIR}/ffmpeg-win64-gpl.zip")
  file(DOWNLOAD
    "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
    "${_FF_ZIP}"
    SHOW_PROGRESS
    TLS_VERIFY ON
    STATUS _DL_STATUS
  )
  list(GET _DL_STATUS 0 _DL_CODE)
  if(NOT _DL_CODE EQUAL 0)
    list(GET _DL_STATUS 1 _DL_MSG)
    message(WARNING "FFmpeg download failed: ${_DL_MSG}. Place ffmpeg.exe in windows/ffmpeg/ or install FFmpeg on PATH.")
    set(_FFMPEG_BUNDLE "")
  else()
    set(_UNZIP "${CMAKE_BINARY_DIR}/_ffmpeg_unzip")
    file(MAKE_DIRECTORY "${_UNZIP}")
    execute_process(
      COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
        "Expand-Archive -LiteralPath '${_FF_ZIP}' -DestinationPath '${_UNZIP}' -Force"
      RESULT_VARIABLE _EX
      OUTPUT_QUIET
      ERROR_QUIET
    )
    if(NOT _EX EQUAL 0)
      message(WARNING "Could not unzip FFmpeg archive. Place ffmpeg.exe in windows/ffmpeg/ manually.")
      set(_FFMPEG_BUNDLE "")
    else()
      file(GLOB _FF_EXE "${_UNZIP}/*/bin/ffmpeg.exe")
      if(_FF_EXE)
        list(GET _FF_EXE 0 _FF_ONE)
        file(COPY "${_FF_ONE}" DESTINATION "${CMAKE_BINARY_DIR}")
        file(RENAME "${CMAKE_BINARY_DIR}/ffmpeg.exe" "${_FFMPEG_CACHE}")
        set(_FFMPEG_BUNDLE "${_FFMPEG_CACHE}")
        message(STATUS "FFmpeg cached at ${_FFMPEG_CACHE}")
      else()
        message(WARNING "ffmpeg.exe not found inside archive. Place it in windows/ffmpeg/ manually.")
        set(_FFMPEG_BUNDLE "")
      endif()
    endif()
  endif()
endif()

if(_FFMPEG_BUNDLE AND EXISTS "${_FFMPEG_BUNDLE}")
  install(FILES "${_FFMPEG_BUNDLE}" DESTINATION "${CMAKE_INSTALL_PREFIX}" RENAME "ffmpeg.exe" COMPONENT Runtime)
  message(STATUS "FFmpeg will be installed next to ${BINARY_NAME}.exe")
endif()
