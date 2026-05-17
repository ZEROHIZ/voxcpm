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

echo [STATUS] Starting OpenAI API Gateway on http://localhost:8089 ...
"%VENV_DIR%\Scripts\python" openai_api.py
pause
