:: hide command
@echo off
::======================================================================
:: name   : deploy.bat
:: desc   £ºadd path and autorun script
:: adap os£ºWindows 7/10/11
:: runtime£ºCMD/PowerShell
::======================================================================

setlocal enabledelayedexpansion

:: init screen
mode con cols=90 lines=25
title env deploy tool
color 9F
cls

::[config]=============================================================
:: PATH
set "TARGET_DIR=win"                    & rem folder to be added to PATH
set "REG_DIR_PATH=HKCU\Environment"     & rem environment variable registry location
set "REG_KEY_PATH=PATH"                 & rem environment variable registry key name
set "REG_TYP_PATH=REG_EXPAND_SZ"        & rem environment variable registry type (expandable string)
:: CMD autorun
set "REG_DIR_CMD_AUTORUN=HKCU\Software\Microsoft\Command Processor" & rem CMD Autorun registry location
set "REG_KEY_CMD_AUTORUN=AutoRun"       & rem CMD Autorun registry key name
set "REG_TYP_CMD_AUTORUN=REG_SZ"        & rem CMD Autorun registry type (string)
set "AUTORUN_BAT=alias.bat"             & rem CMD Autorun script name
::======================================================================

::[raise priv]-------------------------------------------------
@REM %1 mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c %~s0 ::","","runas",1)(window.close)&&exit
@REM if %errorlevel% neq 0 (
@REM     echo   error: pls run as admin
@REM     pause
@REM     exit /b 1
@REM )

::[some var]---------------------------------------------
set "SCRIPT_PATH=%~dp0"
rem stripe trailing backslash
if "%SCRIPT_PATH:~-1%"=="\" set "SCRIPT_PATH=%SCRIPT_PATH:~0,-1%"
echo   script path: %SCRIPT_PATH%
echo.

::[cheke folders and files]-------------------------------------------
echo [1] cheking folders and files...
set "FULL_PATH=%SCRIPT_PATH%\%TARGET_DIR%"
if not exist "%FULL_PATH%" (
    echo   error: cannot find %TARGET_DIR%
    pause
    exit /b 1
)
echo   folder correct: %FULL_PATH%

set "AUTORUN_BAT_PATH=%FULL_PATH%\%AUTORUN_BAT%"
if not exist "%AUTORUN_BAT_PATH%" (
    echo   error: cannot find %AUTORUN_BAT%
    pause
    exit /b 1
)
echo   bat file correct: %AUTORUN_BAT_PATH%
echo.

::[env check]---------------------------------------------
echo [3] cheking environment...
ver | find "10.0.1" > nul && (
    echo   PowerShell find, enable PS adaptation
    set "IS_PS=1"
) || (
    set "IS_PS=0"
)
echo   env check success
echo.

::[path]-----------------------------------------------
echo [4] operating PATH environment variable...
for /f "tokens=1,2*" %%a in ('reg query "%REG_DIR_PATH%" /v "%REG_KEY_PATH%" 2^>nul') do (
    set "PATH_TYPE=%%a"
    set "PATH_VALUE=%%c"
)

:: not find PATH
if not defined PATH_VALUE (
    echo   PATH not found, write new PATH
    set "NEW_PATH=%FULL_PATH%"
    goto :PATH_UPDATE
)

echo   PATH found, check...
echo %PATH_VALUE% | find /i "%FULL_PATH%" > nul
if %errorlevel% equ 0 (
    echo   %FULL_PATH% already exists
    goto :PATH_END
    echo.
) else (
    set "NEW_PATH=%PATH_VALUE%;%FULL_PATH%"
)

:PATH_UPDATE
reg add "%REG_DIR_PATH%" /v "%REG_KEY_PATH%" /t "%REG_TYP_PATH%" /d "%NEW_PATH%" /f > nul
if %errorlevel% neq 0 (
    echo   error: update registry failed! (PATH)
    pause
    exit /b 1
)

echo add new path success: %FULL_PATH%
echo.

:PATH_END
::[cmd autorun doskey reigst]-----------------------------------------------
echo [5] operating CMD autorun...
for /f "tokens=1,2*" %%a in ('reg query "%REG_DIR_CMD_AUTORUN%" /v "%REG_KEY_CMD_AUTORUN%" 2^>nul') do (
    set "CA_TYPE=%%a"
    set "CA_VALUE=%%c"
)

if defined CA_VALUE (
    echo   CMD AUTORUN exist:%CA_VALUE%
    goto :CA_END
)

echo   registry new CDM AUTORUN
set "NEW_CA=%AUTORUN_BAT_PATH%"

reg add "%REG_DIR_CMD_AUTORUN%" /v "%REG_KEY_CMD_AUTORUN%" /t "%REG_TYP_CMD_AUTORUN%" /d "%NEW_CA%" /f
if %errorlevel% neq 0 (
    echo   error: update registry failed! (CMD autorun)
    pause
    exit /b 1
)

echo   CMD AUTORUN registered: %NEW_CA%
echo.

:CA_END

::[refresh]-------------------------------------------------
echo [6] refreshing environment...
if %IS_PS% equ 1 (
    powershell -Command "[Environment]::SetEnvironmentVariable('PATH', '%NEW_PATH%', 'User')"
) else (
    :: cmd need to reopen
    echo   maybe need to reopen CMD to take effect
)
echo.

::[end]-----------------------------------------------------------
echo    FINNISHED!
echo    NOTE:
echo    1. open a new cmd
echo.
pause
exit /b 0