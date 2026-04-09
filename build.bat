@echo off
REM =============================================================================
REM build.bat — The Merry Fields 打包腳本 (Windows)
REM 用法：
REM   build.bat                  打包全平台
REM   build.bat windows          只打 Windows
REM   build.bat macos            只打 macOS
REM   build.bat linux            只打 Linux
REM   build.bat all upload       打包全平台並上傳 itch.io
REM   build.bat windows upload   打包 Windows 並上傳 itch.io
REM
REM 環境變數：
REM   GODOT=godot4               Godot 執行檔路徑
REM   BUTLER=butler              butler 執行檔路徑
REM   VERSION=0.1.0              版本號
REM =============================================================================
setlocal enabledelayedexpansion

REM ── 設定區 ──────────────────────────────────────────────────────────────────
set GAME_NAME=TheMerryFields
if "%VERSION%"==""  set VERSION=0.1.0
if "%GODOT%"==""   set GODOT=godot4
if "%BUTLER%"==""  set BUTLER=butler
set EXPORT_DIR=export
set DIST_DIR=dist

REM 讀取 itch.cfg（若存在）
set ITCH_USER=
set ITCH_GAME=
if exist itch.cfg (
    for /f "usebackq tokens=1,* delims==" %%a in ("itch.cfg") do (
        if "%%a"=="ITCH_USER" set ITCH_USER=%%b
        if "%%a"=="ITCH_GAME" set ITCH_GAME=%%b
    )
)

REM ── 前置檢查 ─────────────────────────────────────────────────────────────────
where %GODOT% >nul 2>&1 || (
    echo [ERROR] 找不到 Godot：%GODOT%
    exit /b 1
)
echo [BUILD] Godot OK
mkdir %DIST_DIR% 2>nul

set TARGET=%1
if "%TARGET%"=="" set TARGET=all
set DO_UPLOAD=%2

if "%DO_UPLOAD%"=="upload" (
    where %BUTLER% >nul 2>&1 || (
        echo [ERROR] 找不到 butler
        echo         安裝說明：https://itch.io/docs/butler/installing.html
        exit /b 1
    )
    if "%ITCH_USER%"=="" (
        echo [ERROR] 未設定 ITCH_USER，請建立 itch.cfg
        exit /b 1
    )
    if "%ITCH_GAME%"=="" (
        echo [ERROR] 未設定 ITCH_GAME，請建立 itch.cfg
        exit /b 1
    )
    echo [BUILD] butler OK
)

REM ── 路由 ─────────────────────────────────────────────────────────────────────
if "%TARGET%"=="windows" ( call :do_windows & goto :after )
if "%TARGET%"=="macos"   ( call :do_macos   & goto :after )
if "%TARGET%"=="linux"   ( call :do_linux   & goto :after )
if "%TARGET%"=="all" (
    call :do_windows
    call :do_macos
    call :do_linux
    goto :after
)
echo [ERROR] 不支援的平台：%TARGET%
exit /b 1

REM ── 各平台子程序 ─────────────────────────────────────────────────────────────
:do_windows
    echo [BUILD] Packing Windows...
    rmdir /s /q %EXPORT_DIR%\windows 2>nul & mkdir %EXPORT_DIR%\windows
    %GODOT% --headless --export-release "Windows Desktop" "%EXPORT_DIR%\windows\%GAME_NAME%.exe"
    echo [BUILD]   Done: %EXPORT_DIR%\windows\%GAME_NAME%.exe
    if "%DO_UPLOAD%"=="upload" (
        echo [BUILD] Uploading windows...
        %BUTLER% push %EXPORT_DIR%\windows %ITCH_USER%/%ITCH_GAME%:windows --userversion %VERSION%
    )
    exit /b 0

:do_macos
    echo [BUILD] Packing macOS...
    rmdir /s /q %EXPORT_DIR%\macos 2>nul & mkdir %EXPORT_DIR%\macos
    %GODOT% --headless --export-release "macOS" "%EXPORT_DIR%\macos\%GAME_NAME%.zip"
    echo [BUILD]   Done: %EXPORT_DIR%\macos\%GAME_NAME%.zip
    if "%DO_UPLOAD%"=="upload" (
        echo [BUILD] Uploading mac...
        %BUTLER% push %EXPORT_DIR%\macos %ITCH_USER%/%ITCH_GAME%:mac --userversion %VERSION%
    )
    exit /b 0

:do_linux
    echo [BUILD] Packing Linux...
    rmdir /s /q %EXPORT_DIR%\linux 2>nul & mkdir %EXPORT_DIR%\linux
    %GODOT% --headless --export-release "Linux/X11" "%EXPORT_DIR%\linux\%GAME_NAME%.x86_64"
    echo [BUILD]   Done: %EXPORT_DIR%\linux\%GAME_NAME%.x86_64
    if "%DO_UPLOAD%"=="upload" (
        echo [BUILD] Uploading linux...
        %BUTLER% push %EXPORT_DIR%\linux %ITCH_USER%/%ITCH_GAME%:linux --userversion %VERSION%
    )
    exit /b 0

:after
    echo [BUILD] Done (v%VERSION%)
    endlocal
