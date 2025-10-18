@echo off
REM Setup Rust environment and run mix ci

set CARGO_HOME=D:\.cargo
set RUSTUP_HOME=D:\.rustup
set PATH=D:\.cargo\bin;%PATH%
set TMPDIR=D:\temp

echo Setting up Rust environment...
echo CARGO_HOME=%CARGO_HOME%
echo RUSTUP_HOME=%RUSTUP_HOME%
echo TMPDIR=%TMPDIR%
echo.

echo Running mix ci...
mix ci
