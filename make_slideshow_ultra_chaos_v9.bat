@echo off
setlocal EnableExtensions EnableDelayedExpansion
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

set "EXIT_CODE=0"
set "SCRIPT_DIR=%~dp0"
if not defined SCRIPT_DIR set "SCRIPT_DIR=%CD%\"


pushd "%SCRIPT_DIR%" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Nie mozna otworzyc folderu skryptu: %SCRIPT_DIR%
  pause
  exit /b 1
)
call :log_line "pushd OK, current dir: %CD%"

set "PS_SCRIPT=%SCRIPT_DIR%make_slideshow_ultra_chaos_v9.ps1"
if not exist "%PS_SCRIPT%" (
  echo [ERROR] make_slideshow_ultra_chaos_v9.ps1 not found. Keep both files in the same folder (with ffmpeg.exe ^& ffprobe.exe).
  set "EXIT_CODE=1"
  call :log_line "missing PowerShell script"
  goto :end_with_pause
)

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" (
  for /f "delims=" %%I in ('where powershell.exe 2^>nul') do (
    set "PS_EXE=%%I"
    goto :ps_found
  )
  for /f "delims=" %%I in ('where pwsh.exe 2^>nul') do (
    set "PS_EXE=%%I"
    goto :ps_found
  )
  echo [ERROR] PowerShell executable not found (powershell.exe / pwsh.exe).
  call :log_line "no PowerShell executable detected"
  set "EXIT_CODE=1"
  goto :show_troubleshooting
)
:ps_found
call :log_line "Using PowerShell executable: %PS_EXE%"

for %%# in ("%PS_SCRIPT%" "ffmpeg.exe" "ffprobe.exe") do (
  if not exist %%~# (
    echo [ERROR] Brak pliku: %%~#
    set "EXIT_CODE=1"
    call :log_line "missing dependency: %%~#"
    goto :end_with_pause
  )
)
call :log_line "Dependencies present"

set "PS_SCRIPT=%SCRIPT_DIR%make_slideshow_ultra_chaos_v9.ps1"
if not exist "%PS_SCRIPT%" (
  echo [ERROR] make_slideshow_ultra_chaos_v9.ps1 not found. Keep both files in the same folder (with ffmpeg.exe ^& ffprobe.exe).
  set "EXIT_CODE=1"
  goto :end_with_pause
)

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=powershell.exe"

for %%# in ("%PS_SCRIPT%" "ffmpeg.exe" "ffprobe.exe") do (
  if not exist %%~# (
    echo [ERROR] Brak pliku: %%~#
    set "EXIT_CODE=1"
    goto :end_with_pause
  )
)

set "RECURSE_FLAG="
if "%RECURSE%"=="1" set "RECURSE_FLAG=-Recurse"
set "VERBOSE_FLAG="
if "%VERBOSE%"=="1" set "VERBOSE_FLAG=-VerboseMode"
set "RESUME_FLAG="
if "%RESUME%"=="1" set "RESUME_FLAG=-Resume"


"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" ^
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
set "EXIT_CODE=%ERRORLEVEL%"
call :log_line "PowerShell exit code: %EXIT_CODE%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] PowerShell zakonczyl sie z kodem %EXIT_CODE%.
  goto :show_troubleshooting
)

set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] PowerShell zakonczyl sie z kodem %EXIT_CODE%.
  goto :end_with_pause
)

echo.
echo (Sprawdz log: _tmp_ultra_v9\make.log)


:end_with_pause
pause
popd >nul 2>&1
exit /b %EXIT_CODE%
