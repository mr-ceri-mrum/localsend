FFmpeg (https://ffmpeg.org) is bundled with the Windows build for converting
HEIC photos and iOS video (e.g. MOV) to formats Windows plays without extra codecs.

The official installer downloads a prebuilt binary during the first CMake configure
(see ../cmake/bundle_ffmpeg.cmake). You can also place ffmpeg.exe in this folder
manually (e.g. for offline builds) — it will be used instead of downloading.

Source code and license: https://github.com/BtbN/FFmpeg-Builds and https://ffmpeg.org/legal.html
