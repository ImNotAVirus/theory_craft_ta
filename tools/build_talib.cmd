@echo off
REM Build script for ta-lib C library on Windows
REM Based on ta-lib-python build scripts

setlocal enabledelayedexpansion

REM Setup CMake - use CMAKE_PATH env var if set
if defined CMAKE_PATH (
    set "PATH=%CMAKE_PATH%;%PATH%"
    echo Using CMake from CMAKE_PATH: %CMAKE_PATH%
)

REM Setup Visual Studio environment for MSVC compiler
REM Search for vcvarsall.bat in common Visual Studio locations
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set "VS_PATH=%%i"
    )
    if defined VS_PATH (
        if exist "!VS_PATH!\VC\Auxiliary\Build\vcvarsall.bat" (
            echo Configuring Visual Studio environment...
            call "!VS_PATH!\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul
            if errorlevel 1 (
                echo Warning: Failed to configure Visual Studio environment
            ) else (
                echo Visual Studio environment configured
            )
        )
    )
) else (
    echo Warning: vswhere.exe not found - trying without Visual Studio setup
    echo If build fails, ensure Visual Studio Build Tools are installed
)

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
cmake --install . --config Release --prefix "%INSTALL_DIR%"

if errorlevel 1 (
    echo Error: Install failed
    exit /B 1
)

REM Normalize library name for cross-platform compatibility
REM Copy ta-lib-static.lib to ta_lib.lib so Rust can find it with the same name on all platforms
if exist "%INSTALL_DIR%\lib\ta-lib-static.lib" (
    echo Normalizing library name to ta_lib.lib...
    copy /Y "%INSTALL_DIR%\lib\ta-lib-static.lib" "%INSTALL_DIR%\lib\ta_lib.lib" >nul
    if errorlevel 1 (
        echo Warning: Failed to copy library to normalized name
    )
)

endlocal

echo TA-Lib %TALIB_VERSION% built and installed successfully!
echo Library location: %INSTALL_DIR%\lib
echo Headers location: %INSTALL_DIR%\include
