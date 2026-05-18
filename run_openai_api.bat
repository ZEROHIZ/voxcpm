@echo off
title VoxCPM2 OpenAI API Gateway Launcher
echo ==================================================================
echo     VoxCPM2 OpenAI-Compatible API Gateway Launcher
echo ==================================================================

set VENV_DIR=.venv
set OMP_NUM_THREADS=4
set MKL_NUM_THREADS=4
set OPENBLAS_NUM_THREADS=4
set VECLIB_MAXIMUM_THREADS=4
set NUMEXPR_NUM_THREADS=4
set SETUPTOOLS_SCM_PRETEND_VERSION=0.0.0

if not exist "%VENV_DIR%" (
    echo [ERROR] Virtual environment .venv not found!
    echo Please run run_local.bat first to set up the environment.
    pause
    exit /b 1
)

:LAUNCH_API
echo [STATUS] Starting OpenAI API Gateway on http://localhost:8089 ...
"%VENV_DIR%\Scripts\python" openai_api.py
set EXIT_CODE=%errorlevel%
echo ==================================================================
echo     Application exited with code: %EXIT_CODE%
echo ==================================================================
if "%EXIT_CODE%"=="3" (
    echo [RESTART] Force restart signal detected (exit code 3).
    echo           Re-launching API Gateway in 2 seconds...
    ping 127.0.0.1 -n 3 >nul
    goto LAUNCH_API
)
pause
