@echo off
REM Run benchmark with proper environment setup
REM Usage: .tools\run_benchmark.cmd benchmarks\ema_benchmark.exs

if "%1"=="" (
    echo Usage: .tools\run_benchmark.cmd ^<benchmark_file^>
    echo Example: .tools\run_benchmark.cmd benchmarks\ema_benchmark.exs
    exit /b 1
)

REM Setup Rust environment
set CARGO_HOME=D:\.cargo
set RUSTUP_HOME=D:\.rustup
set PATH=D:\.cargo\bin;%PATH%
set TMPDIR=D:\temp

REM Setup Mix environment for benchmarking
set MIX_ENV=bench

echo Setting up benchmark environment...
echo CARGO_HOME=%CARGO_HOME%
echo RUSTUP_HOME=%RUSTUP_HOME%
echo TMPDIR=%TMPDIR%
echo MIX_ENV=%MIX_ENV%
echo.

echo Running benchmark: %1
echo.

mix run %1
