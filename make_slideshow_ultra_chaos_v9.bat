@echo off
setlocal EnableDelayedExpansion
title ULTRA CHAOS slideshow v9 - by ChatGPT

REM ======= KONFIG =======
set "OVERLAP_RATIO=0.90"
set "FPS=30"
set "WIDTH=1920"
set "HEIGHT=1080"
set "CRF=20"
set "CHUNK_SIZE=60"
set "START_CHUNK=0"
set "END_CHUNK=-1"
set "MAX_XFADE=55"
set "PRESET=veryfast"
set "RECURSE=0"
set "RESUME=1"
set "VERBOSE=1"

if not exist "make_slideshow_ultra_chaos_v9.ps1" (
  echo [ERROR] make_slideshow_ultra_chaos_v9.ps1 not found. Keep both files in the same folder (with ffmpeg.exe & ffprobe.exe).
  pause
  exit /b 1
)

set "RECURSE_FLAG="
if "%RECURSE%"=="1" set "RECURSE_FLAG=-Recurse"
set "VERBOSE_FLAG="
if "%VERBOSE%"=="1" set "VERBOSE_FLAG=-VerboseMode"
set "RESUME_FLAG="
if "%RESUME%"=="1" set "RESUME_FLAG=-Resume"

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_slideshow_ultra_chaos_v9.ps1" ^
  -OverlapRatio %OVERLAP_RATIO% ^
  -FPS %FPS% ^
  -WIDTH %WIDTH% ^
  -HEIGHT %HEIGHT% ^
  -CRF %CRF% ^
  -ChunkSize %CHUNK_SIZE% ^
  -StartChunk %START_CHUNK% ^
  -EndChunk %END_CHUNK% ^
  -MaxXfade %MAX_XFADE% ^
  -Preset %PRESET% ^
  %RECURSE_FLAG% ^
  %RESUME_FLAG% ^
  %VERBOSE_FLAG%

echo.
echo (Sprawdz log: _tmp_ultra_v9\make.log)
pause
