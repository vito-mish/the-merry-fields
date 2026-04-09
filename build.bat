@echo off
REM =============================================================================
REM build.bat — The Merry Fields 打包腳本 (Windows)
REM 用法：
REM   build.bat              打包全平台
REM   build.bat windows      只打 Windows
REM   build.bat macos        只打 macOS
REM   build.bat linux        只打 Linux
REM   build.bat all upload   打包後上傳 Steam
REM =============================================================================
setlocal enabledelayedexpansion

REM ── 設定區 ──────────────────────────────────────────────────────────────────
set GAME_NAME=TheMerryFields
set VERSION=0.1.0
if "%GODOT%"=="" set GODOT=godot4
if "%STEAMCMD%"=="" set STEAMCMD=steamcmd
set EXPORT_DIR=export
set DIST_DIR=dist
set STEAM_SCRIPT=steam\app_build.vdf

REM ── 前置檢查 ─────────────────────────────────────────────────────────────────
where %GODOT% >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 找不到 Godot：%GODOT%
    echo         請安裝 Godot 4 並確認在 PATH，或設定 GODOT 環境變數
    exit /b 1
)

echo [BUILD] Godot：%GODOT%
mkdir %DIST_DIR% 2>nul

set TARGET=%1
if "%TARGET%"=="" set TARGET=all
set UPLOAD=%2

REM ── 執行打包 ─────────────────────────────────────────────────────────────────
if "%TARGET%"=="windows" goto :build_windows
if "%TARGET%"=="macos"   goto :build_macos
if "%TARGET%"=="linux"   goto :build_linux
if "%TARGET%"=="all"     goto :build_all

echo [ERROR] 不支援的平台：%TARGET%
exit /b 1

:build_all
    call :do_windows
    call :do_macos
    call :do_linux
    goto :after_build

:build_windows
    call :do_windows
    goto :after_build

:build_macos
    call :do_macos
    goto :after_build

:build_linux
    call :do_linux
    goto :after_build

REM ── 各平台子程序 ─────────────────────────────────────────────────────────────
:do_windows
    echo [BUILD] Packing Windows...
    rmdir /s /q %EXPORT_DIR%\windows 2>nul
    mkdir %EXPORT_DIR%\windows
    %GODOT% --headless --export-release "Windows Desktop" ^
        "%EXPORT_DIR%\windows\%GAME_NAME%.exe"
    call :write_appid %EXPORT_DIR%\windows
    powershell -command "Compress-Archive -Path '%EXPORT_DIR%\windows\*' -DestinationPath '%DIST_DIR%\%GAME_NAME%-%VERSION%-windows.zip' -Force"
    echo [BUILD]   Done: %DIST_DIR%\%GAME_NAME%-%VERSION%-windows.zip
    exit /b 0

:do_macos
    echo [BUILD] Packing macOS...
    rmdir /s /q %EXPORT_DIR%\macos 2>nul
    mkdir %EXPORT_DIR%\macos
    %GODOT% --headless --export-release "macOS" ^
        "%EXPORT_DIR%\macos\%GAME_NAME%.zip"
    call :write_appid %EXPORT_DIR%\macos
    copy /y "%EXPORT_DIR%\macos\%GAME_NAME%.zip" ^
            "%DIST_DIR%\%GAME_NAME%-%VERSION%-macos.zip"
    echo [BUILD]   Done: %DIST_DIR%\%GAME_NAME%-%VERSION%-macos.zip
    exit /b 0

:do_linux
    echo [BUILD] Packing Linux...
    rmdir /s /q %EXPORT_DIR%\linux 2>nul
    mkdir %EXPORT_DIR%\linux
    %GODOT% --headless --export-release "Linux/X11" ^
        "%EXPORT_DIR%\linux\%GAME_NAME%.x86_64"
    call :write_appid %EXPORT_DIR%\linux
    powershell -command "Compress-Archive -Path '%EXPORT_DIR%\linux\*' -DestinationPath '%DIST_DIR%\%GAME_NAME%-%VERSION%-linux.zip' -Force"
    echo [BUILD]   Done: %DIST_DIR%\%GAME_NAME%-%VERSION%-linux.zip
    exit /b 0

:write_appid
    if exist "%STEAM_SCRIPT%" (
        for /f "tokens=2 delims= " %%a in ('findstr /i "appid" "%STEAM_SCRIPT%"') do (
            set APPID=%%~a
        )
        echo !APPID!>"%~1\steam_appid.txt"
    )
    exit /b 0

REM ── Steam 上傳 ───────────────────────────────────────────────────────────────
:after_build
    if "%UPLOAD%"=="upload" (
        echo [BUILD] Uploading to Steam...
        if not exist "%STEAM_SCRIPT%" (
            echo [ERROR] 找不到 Steam 腳本：%STEAM_SCRIPT%
            exit /b 1
        )
        %STEAMCMD% +login anonymous +run_app_build "%STEAM_SCRIPT%" +quit
        echo [BUILD]   Upload complete
    )

    echo [BUILD] Done (v%VERSION%)
    dir /b %DIST_DIR%\*.zip 2>nul
    endlocal
