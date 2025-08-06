@echo off

setlocal enabledelayedexpansion

::[script config]===========================================================
set "PROXY_IP=127.0.0.1"            & rem localhost IP
set "DEFAULT_PORT=7897"             & rem default proxy port
set "PROXY_PORT=%DEFAULT_PORT%"     & rem current port config
set "ALIAS_NAME=%~n0"               & rem script name without extension

set "SCRIPT_PATH=%~dp0"             & rem script path
                                    rem scripe path may have trailing backslash
if "%SCRIPT_PATH:~-1%"=="\" set "SCRIPT_PATH=%SCRIPT_PATH:~0,-1%"

set "CONFIG_FILE=%SCRIPT_PATH%\port"  & rem config file for proxy port
::======================================================================

::[script switch perem]==========================================================
if "%~1"==""        goto :FULL_INSTALL
if "%1"=="install"  goto :READ_PORT
if "%1"=="port"     goto :SET_PORT
if "%1"=="help"     goto :HELP

:FULL_INSTALL
set "FROM_BEGINNING=1"

::[read config]========================================================
:READ_PORT

:: check config files
if not exist "%CONFIG_FILE%" (
    echo port config not exist, set a port now...
    goto :SET_PORT
)

set /p FILE_CONTENT=<"%CONFIG_FILE%"
rem stripe trailing spaces
set "FILE_CONTENT=%FILE_CONTENT: =%"

call :CHECK_PORT "%FILE_CONTENT%" VALID
if not "%VALID%"=="1" (
    goto :SET_PORT
)

set "PROXY_PORT=%FILE_CONTENT%"

::[doskey install]========================================================
:INSTALL
@REM echo [doskey] regitering alias commands...

doskey proxy=set "http_proxy=http://%PROXY_IP%:%DEFAULT_PORT%" $T set "https_proxy=http://%PROXY_IP%:%DEFAULT_PORT%" $T echo proxy set to: http://%PROXY_IP%:%DEFAULT_PORT%
doskey unproxy=set "http_proxy=" $T set "https_proxy=" $T echo proxy settings cleared.

echo [doskey] available commands:   proxy, unproxy
echo [doskey] other usage:          %ALIAS_NAME% help
@REM echo [doskey] SUCCESS and END
exit /b 0

::[set port]========================================================
:SET_PORT

:SET_PORT_input_loop
echo.
set "INPUT_PORT="
set /p INPUT_PORT=input port (1-65535):

if not defined INPUT_PORT (
    echo invalid: port cannot be empty.
    timeout /t 2 >nul
    goto :SET_PORT_input_loop
)

call :CHECK_PORT "%INPUT_PORT%" VALID
if not "%VALID%"=="1" (
    echo invalid: port must be a number between 1 and 65535.
    timeout /t 2 >nul
    goto :SET_PORT_input_loop
)

set "PROXY_PORT=%INPUT_PORT%"
echo save port to config: %CONFIG_FILE%
echo !PROXY_PORT! > "%CONFIG_FILE%"

echo.

if defined FROM_BEGINNING (
    goto :FULL_INSTALL
)

exit /b 0

::[port checker]====================================================
:CHECK_PORT
set "val=%~1"
set "%~2=0"

:: check empty
if not defined val exit /b

:: check is number
set /a test=0+%val% 2>nul && (
    for %%i in (%val%) do if not "%%i"=="%val%" exit /b
) || exit /b


set /a num=%val%
:: 1-65535
if %num% geq 1 if %num% leq 65535 (
    set "%~2=1"
)

exit /b

::[help]===========================================================
:HELP
echo usage: %ALIAS_NAME% [command]
echo   %ALIAS_NAME%             - install alias commands
echo   %ALIAS_NAME% install     - install alias commands
echo   %ALIAS_NAME% port        - set proxy port
echo   %ALIAS_NAME% help        - print this help message
exit /b 0
