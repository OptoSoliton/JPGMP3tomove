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

set "TMP_ROOT=%SCRIPT_DIR%_tmp_ultra_v9"
if not exist "%TMP_ROOT%" mkdir "%TMP_ROOT%" >nul 2>&1
set "LAUNCH_LOG=%TMP_ROOT%\launcher.log"
call :log_init

call :log_line "Launcher started by %USERNAME% on %COMPUTERNAME%"
call :log_line "Script dir guess: %SCRIPT_DIR%"
pushd "%SCRIPT_DIR%" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Nie mozna otworzyc folderu skryptu: %SCRIPT_DIR%
  call :log_line "pushd failed for %SCRIPT_DIR%"
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

set "RECURSE_FLAG="
if "%RECURSE%"=="1" set "RECURSE_FLAG=-Recurse"
set "VERBOSE_FLAG="
if "%VERBOSE%"=="1" set "VERBOSE_FLAG=-VerboseMode"
set "RESUME_FLAG="
if "%RESUME%"=="1" set "RESUME_FLAG=-Resume"

call :log_line "Invoking PowerShell script"
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

echo.
echo (Sprawdz log: _tmp_ultra_v9\make.log)
call :log_line "Launcher completed successfully"

:end_with_pause
pause
popd >nul 2>&1
exit /b %EXIT_CODE%

:show_troubleshooting
call :log_line "Showing troubleshooting hints (EXIT=%EXIT_CODE%)"
echo.
echo ===== TROUBLESHOOTING =====
echo 1) Upewnij sie, ze ffmpeg.exe, ffprobe.exe i oba skrypty sa w tym samym folderze.
echo 2) Jesli bledy pojawiaja sie natychmiast, otworz notatnikiem log: %LAUNCH_LOG%
echo 3) Mozesz tez odpalic PowerShell recznie: "%PS_EXE%" -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
echo 4) Jesli PowerShell jest zablokowany, uruchom CMD jako administrator i ponow probe.
echo ===========================
if exist "%LAUNCH_LOG%" (
  call :log_line "Opening launcher log for review"
  start "" notepad.exe "%LAUNCH_LOG%" >nul 2>&1
)
goto :end_with_pause

:log_init
if exist "%LAUNCH_LOG%" del "%LAUNCH_LOG%" >nul 2>&1
>"%LAUNCH_LOG%" echo ===== ULTRA CHAOS launcher log =====
>>"%LAUNCH_LOG%" echo [%DATE% %TIME%] init
call :log_line "Args: %*"
call :log_line "Launcher log path: %LAUNCH_LOG%"
call :log_line "Temp root: %TMP_ROOT%"
exit /b 0

:log_line
if not defined LAUNCH_LOG exit /b 0
setlocal DisableDelayedExpansion
set "_RAW=%~1"
setlocal EnableDelayedExpansion
set "_LOG_MSG=%_RAW%"
set "_LOG_MSG=!_LOG_MSG:^=^^^^!"
set "_LOG_MSG=!_LOG_MSG:!=^!!"
set "_LOG_MSG=!_LOG_MSG:&=^&!"
set "_LOG_MSG=!_LOG_MSG:|=^|!"
set "_LOG_MSG=!_LOG_MSG:>=^>!"
set "_LOG_MSG=!_LOG_MSG:<=^<!"
>>"%LAUNCH_LOG%" echo [%DATE% %TIME%] !_LOG_MSG!
endlocal & endlocal
exit /b 0
