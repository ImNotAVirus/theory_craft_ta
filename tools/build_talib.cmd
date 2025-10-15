@echo off
REM Build script for ta-lib C library on Windows
REM Based on ta-lib-python build scripts

setlocal enabledelayedexpansion

if not defined TALIB_VERSION set TALIB_VERSION=0.6.4
set INSTALL_DIR=%CD%\ta-lib-install

echo Building TA-Lib version %TALIB_VERSION%
echo Install directory: %INSTALL_DIR%

REM Download TA-Lib from GitHub
echo Downloading TA-Lib %TALIB_VERSION%...
curl -L -o talib-%TALIB_VERSION%.zip https://github.com/TA-Lib/ta-lib/archive/refs/tags/v%TALIB_VERSION%.zip

if errorlevel 1 (
    echo Error: Failed to download TA-Lib
    exit /B 1
)

REM Extract archive using PowerShell
echo Extracting archive...
powershell -Command "Expand-Archive -Path 'talib-%TALIB_VERSION%.zip' -DestinationPath '.' -Force"

if errorlevel 1 (
    echo Error: Failed to extract TA-Lib
    exit /B 1
)

REM Navigate to extracted directory
cd ta-lib-%TALIB_VERSION%

REM Copy headers to include/ta-lib/ subdirectory
echo Copying headers...
if not exist include\ta-lib mkdir include\ta-lib
copy /Y include\*.h include\ta-lib\ >nul

REM Create build directory
if not exist _build mkdir _build
cd _build

REM Configure with CMake
echo Configuring with CMake...
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR% ..

if errorlevel 1 (
    echo Error: CMake configuration failed
    exit /B 1
)

REM Build with NMake or MSBuild
echo Building TA-Lib...
cmake --build . --config Release

if errorlevel 1 (
    echo Error: Build failed
    exit /B 1
)

REM Install
echo Installing to %INSTALL_DIR%...
cmake --install . --config Release

if errorlevel 1 (
    echo Error: Install failed
    exit /B 1
)

endlocal

echo TA-Lib %TALIB_VERSION% built and installed successfully!
echo Library location: %INSTALL_DIR%\lib
echo Headers location: %INSTALL_DIR%\include
